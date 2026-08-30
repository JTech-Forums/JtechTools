# frozen_string_literal: true

module DiscourseDisteleplus
  # Compatibility name retained for Telegram setup/status commands. This now
  # manages native conversation state and has no dependency on Discourse Chat.
  module ChannelNotifications
    Report =
      Struct.new(
        :eligible,
        :enrolled,
        :updated,
        :without_push_subscription,
        :push_prompt,
        :push_devices,
        keyword_init: true,
      )

    def self.active?
      SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_force_channel_notifications
    end

    def self.push_prompt_enabled?
      SiteSetting.respond_to?(:push_notifications_prompt) && SiteSetting.push_notifications_prompt
    end

    def self.push_device_count
      defined?(::PushSubscription) ? ::PushSubscription.count : 0
    rescue StandardError
      0
    end

    def self.enforce_all!
      return nil unless active?

      report =
        Report.new(
          eligible: 0,
          enrolled: 0,
          updated: 0,
          without_push_subscription: 0,
          push_prompt: push_prompt_enabled?,
          push_devices: push_device_count,
        )
      Access.allowed_users.find_each do |user|
        report.eligible += 1
        outcome = enforce_user!(user)
        report.enrolled += 1 if outcome&.dig(:enrolled)
        report.updated += 1 if outcome&.dig(:updated)
        report.without_push_subscription += 1 unless outcome&.dig(:has_push)
      end
      Rails.logger.info(
        "#{DiscourseDisteleplus::LOG_TAG} native notification sync: " \
          "eligible=#{report.eligible} newly_enrolled=#{report.enrolled} " \
          "updated=#{report.updated} no_push_subscription=#{report.without_push_subscription} " \
          "push_prompt=#{report.push_prompt} push_devices=#{report.push_devices}",
      )
      report
    end

    def self.enforce_user!(user)
      return nil unless active? && Access.allowed?(user)

      state = UserState.find_or_initialize_by(user: user)
      enrolled = state.new_record?
      updated = !state.notification_level_always?
      state.notification_level = :always
      state.save! if state.changed?
      {
        enrolled: enrolled,
        updated: updated,
        has_push:
          defined?(::PushSubscription) && PushSubscription.exists?(user_id: user.id),
      }
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} native notification enrollment failed for " \
          "user #{user&.id}: #{e.message}",
      )
      nil
    end

    def self.status_summary
      return "off" unless active?

      total = Access.allowed_users.count
      always =
        UserState
          .where(user_id: Access.allowed_users.select(:id))
          .where(notification_level: UserState.notification_levels[:always])
          .count
      prompt = push_prompt_enabled? ? "push prompt on" : "push prompt OFF in site settings"
      "on — #{always}/#{total} native members at always, #{prompt}, " \
        "#{push_device_count} devices subscribed"
    rescue StandardError => e
      "on (status unavailable: #{e.message})"
    end
  end
end
