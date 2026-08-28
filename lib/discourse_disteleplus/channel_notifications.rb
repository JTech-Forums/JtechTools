# frozen_string_literal: true

module DiscourseDisteleplus
  # Keeps every eligible user enrolled in the bridge channel at notification
  # level "always", so core's chat notifier actually fans out desktop alerts
  # and web-push for each message — including the ones the bridge posts on
  # behalf of Telegram senders.
  #
  # Why this exists: chat only pushes to members whose membership says
  # "always", and a locked chat UI (disteleplus_lock_chat_ui) leaves people
  # no obvious place to change that. The lock made the channel the ONLY
  # conversation; this makes sure nobody silently misses it.
  #
  # Two layers:
  #   * enforce_all!/enforce_user! — bulk/one-shot reconciliation, run by the
  #     scheduled sync job, the settings button, and user/group events.
  #   * a before_save prepend on Chat::UserChatChannelMembership (wired in
  #     sub_plugins/disteleplus.rb via `pin_membership_attributes`) that snaps
  #     any later preference change straight back to "always".
  #
  # Schema drift is handled defensively: the current chat plugin has a single
  # `notification_level`; older ones had desktop_/mobile_notification_level.
  # Whatever the row responds to is set.
  module ChannelNotifications
    BATCH_SIZE = 500

    Report =
      Struct.new(
        :channel_id,
        :eligible,
        :enrolled,
        :updated,
        :chat_disabled_fixed,
        :without_push_subscription,
        :push_prompt,
        :push_devices,
        keyword_init: true,
      )

    def self.active?
      return false unless SiteSetting.disteleplus_enabled
      return false unless SiteSetting.disteleplus_force_channel_notifications
      return false unless SiteSetting.disteleplus_chat_channel_id.to_i.positive?
      return false unless ChatAdapter.available?
      # `defined?` yields a String, not a boolean — keep the predicate honest.
      return false unless defined?(::Chat::UserChatChannelMembership)
      true
    end

    # Core has no on/off switch for web push: a browser subscribes (usually
    # via the push_notifications_prompt banner) and PostAlerter pushes to
    # every PushSubscription. So "is push working" reduces to whether the
    # prompt is on and how many devices have subscribed.
    def self.push_prompt_enabled?
      SiteSetting.respond_to?(:push_notifications_prompt) &&
        SiteSetting.push_notifications_prompt == true
    end

    def self.push_device_count
      defined?(::PushSubscription) ? ::PushSubscription.count : 0
    rescue StandardError
      0
    end

    def self.channel
      return nil unless active?
      ::Chat::Channel.find_by(id: SiteSetting.disteleplus_chat_channel_id)
    end

    def self.bridge_channel_id?(channel_id)
      channel_id.to_i == SiteSetting.disteleplus_chat_channel_id.to_i
    end

    # Reconciles everyone. Returns a Report (also logged) or nil when inactive.
    def self.enforce_all!
      target = channel
      return nil if target.nil?

      report =
        Report.new(
          channel_id: target.id,
          eligible: 0,
          enrolled: 0,
          updated: 0,
          chat_disabled_fixed: 0,
          without_push_subscription: 0,
          push_prompt: push_prompt_enabled?,
          push_devices: push_device_count,
        )

      eligible_users(target).find_each(batch_size: BATCH_SIZE) do |user|
        report.eligible += 1
        outcome = enforce_user!(user, channel: target)
        next if outcome.nil?
        report.enrolled += 1 if outcome[:enrolled]
        report.updated += 1 if outcome[:updated]
        report.chat_disabled_fixed += 1 if outcome[:chat_enabled_fixed]
        report.without_push_subscription += 1 unless outcome[:has_push]
      end

      Rails.logger.info(
        "#{DiscourseDisteleplus::LOG_TAG} notification sync: channel=#{report.channel_id} " \
          "eligible=#{report.eligible} newly_enrolled=#{report.enrolled} " \
          "updated=#{report.updated} chat_reenabled=#{report.chat_disabled_fixed} " \
          "no_push_subscription=#{report.without_push_subscription} " \
          "push_prompt=#{report.push_prompt} push_devices=#{report.push_devices}",
      )
      report
    end

    # Enrolls/pins one user. Returns an outcome hash, or nil when the user is
    # not eligible or the feature is inactive.
    def self.enforce_user!(user, channel: nil)
      target = channel || self.channel
      return nil if target.nil? || user.nil?
      return nil unless eligible?(user, target)

      outcome = { enrolled: false, updated: false, chat_enabled_fixed: false, has_push: false }

      # Chat is opt-out per user; a member who turned it off would never be
      # notified no matter what the membership says.
      option = user.user_option
      if option && option.respond_to?(:chat_enabled) && option.chat_enabled == false
        option.update_column(:chat_enabled, true)
        outcome[:chat_enabled_fixed] = true
      end

      membership =
        ::Chat::UserChatChannelMembership.find_by(user_id: user.id, chat_channel_id: target.id)
      if membership.nil?
        membership = follow(target, user)
        return nil if membership.nil?
        outcome[:enrolled] = true
      end

      unless membership.following
        membership.following = true
        outcome[:updated] = true
      end
      outcome[:updated] = true if pin_membership_attributes(membership)
      membership.save! if membership.changed?

      outcome[:has_push] = defined?(::PushSubscription) &&
        ::PushSubscription.exists?(user_id: user.id)
      outcome
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} notification enforce failed for user #{user&.id}: " \
          "#{e.class}: #{e.message}",
      )
      nil
    end

    # Sets the "always" level on a membership row, whatever the schema calls
    # it. Returns true when something changed. Pure attribute work — the
    # caller saves — so the same helper serves the before_save prepend.
    def self.pin_membership_attributes(membership)
      changed = false
      if membership.respond_to?(:notification_level=) &&
           membership.notification_level.to_s != "always"
        membership.notification_level = :always
        changed = true
      end
      %i[desktop_notification_level mobile_notification_level].each do |attr|
        next unless membership.respond_to?(:"#{attr}=")
        next if membership.public_send(attr).to_s == "always"
        membership.public_send(:"#{attr}=", :always)
        changed = true
      end
      if membership.respond_to?(:muted=) && membership.muted
        membership.muted = false
        changed = true
      end
      changed
    end

    # Users who are allowed into chat at all and can join this channel.
    # Restricting to chat_allowed_groups first keeps the per-user guardian
    # check off the bulk of a large forum's user table.
    def self.eligible_users(target)
      scope = ::User.real.activated.not_suspended.not_silenced.not_staged
      scope = scope.where(id: ::GroupUser.where(group_id: chat_allowed_group_ids).select(:user_id))
      scope.where.not(id: bot_user_ids).includes(:user_option).order(:id)
    end

    def self.eligible?(user, target)
      return false if bot_user_ids.include?(user.id)
      return false unless user.active && !user.staged && !user.suspended? && !user.silenced?
      guardian = ::Guardian.new(user)
      if guardian.respond_to?(:can_join_chat_channel?)
        guardian.can_join_chat_channel?(target)
      elsif guardian.respond_to?(:can_preview_chat_channel?)
        guardian.can_preview_chat_channel?(target)
      else
        true
      end
    rescue StandardError
      false
    end

    def self.chat_allowed_group_ids
      ids = SiteSetting.chat_allowed_groups_map if SiteSetting.respond_to?(:chat_allowed_groups_map)
      ids = SiteSetting.chat_allowed_groups.to_s.split("|").map(&:to_i) if ids.blank?
      # Everyone (group 0) means "no group restriction" — expand to the
      # automatic everyone group so the GroupUser join still works.
      ids = ids.map { |id| id.zero? ? ::Group::AUTO_GROUPS[:everyone] : id }
      ids.presence || [::Group::AUTO_GROUPS[:trust_level_0]]
    end

    def self.bot_user_ids
      ids = [::Discourse::SYSTEM_USER_ID]
      bot = DiscourseDisteleplus.bot_user
      ids << bot.id if bot
      ids
    end

    def self.follow(target, user)
      if defined?(::Chat::ChannelMembershipManager)
        ::Chat::ChannelMembershipManager.new(target).follow(user)
      else
        ::Chat::UserChatChannelMembership.create!(
          user_id: user.id,
          chat_channel_id: target.id,
          following: true,
        )
      end
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} follow failed for user #{user.id}: #{e.message}",
      )
      nil
    end

    # Human summary for /disteleplus_status and the sync log.
    def self.status_summary
      return "off" unless SiteSetting.disteleplus_force_channel_notifications
      return "on, waiting for a chat channel id" unless active?
      target = channel
      return "on, channel #{SiteSetting.disteleplus_chat_channel_id} not found" if target.nil?

      total =
        ::Chat::UserChatChannelMembership.where(chat_channel_id: target.id, following: true).count
      always =
        if ::Chat::UserChatChannelMembership.column_names.include?("notification_level")
          ::Chat::UserChatChannelMembership
            .where(chat_channel_id: target.id, following: true)
            .where(
              notification_level: ::Chat::UserChatChannelMembership.notification_levels[:always],
            )
            .count
        else
          total
        end
      prompt = push_prompt_enabled? ? "push prompt on" : "push prompt OFF in site settings"
      "on — #{always}/#{total} members at always, #{prompt}, #{push_device_count} devices subscribed"
    rescue StandardError => e
      "on (status unavailable: #{e.message})"
    end
  end
end
