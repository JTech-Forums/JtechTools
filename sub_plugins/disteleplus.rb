# frozen_string_literal: true
# Jtech sub-plugin: Disteleplus — Telegram ⇄ Discourse Chat bridge.
#
# Bridges exactly ONE Telegram group with exactly ONE Discourse Chat channel,
# two-way. Use case: the admin team chats in a Telegram group; an admin
# without Telegram participates through a TL4-restricted chat channel and
# both sides see a single conversation.
#
# Inbound (Telegram → Discourse): Telegram pushes updates to a secret-guarded
# webhook (see routes.rb / WebhookController); a Sidekiq job feeds them to
# UpdateProcessor, which posts into the channel — AS the matching Discourse
# user when the Telegram username maps to one (manual mapping setting wins
# over the automatic same-username match), otherwise as the bridge-bot user
# with a "**Name (TG):**" prefix. Media within the size cap is re-uploaded;
# replies, edits, polls (rendered as markdown) and reactions are mirrored.
#
# Outbound (Discourse → Telegram): the chat plugin's DiscourseEvents enqueue
# a send job; the bot posts with a "<b>username:</b>" prefix (bots cannot
# impersonate), edits/deletes its linked messages, and mirrors at most ONE
# reaction per message (a Bot API hard limit).
#
# Echo suppression is two-layered: a thread-local flag while the bridge
# itself writes to chat (DiscourseEvent.trigger is synchronous, so our own
# writes' events are skipped on the spot), plus the persistent
# disteleplus_message_links table.
#
# Known-impossible by Bot API design, documented rather than faked: Telegram
# never reports message deletions to bots, so TG-side deletions leave the
# Discourse copy in place.
#
# The optional "chat lock" mode points the chat button straight at the
# bridge channel and blocks creating channels, DMs and threads for EVERYONE
# (admins included) — UI hidden client-side, enforced by Guardian and
# Chat::Channel prepends server-side. Admins may optionally keep browsing
# the hub pages; nothing lets anyone create.
#
# Channel notifications: every eligible user is enrolled in the bridge
# channel at level "always" and pinned there (ChannelNotifications), so
# chat's own notifier delivers desktop alerts + web push for each message.
#
# Voice notes: a composer mic button records in-browser and posts the note
# as an upload; a custom player renders chat audio; outbound notes reach
# Telegram as real voice bubbles via sendVoice (VoiceNotes).
#
# All chat-plugin API touchpoints live in ChatAdapter so the whole module
# no-ops gracefully when the chat plugin is absent (translator_tweaks
# precedent).

register_asset "stylesheets/disteleplus.scss"

module ::DiscourseDisteleplus
  LOG_TAG = "[jtech-tools disteleplus]"

  def self.chat_available?
    ChatAdapter.available?
  end

  # The user that posts unmatched Telegram messages and owns nothing else.
  # Looked up per call (multisite-safe, and cheap); lazily created on first
  # use. Point the setting at an existing username to reuse a user instead.
  def self.bot_user
    username = SiteSetting.disteleplus_bridge_bot_username.to_s.strip
    return nil if username.blank?
    User.find_by_username(username) || create_bot_user!(username)
  end

  def self.create_bot_user!(username)
    user =
      User.create!(
        username: username,
        name: "Telegram Bridge",
        email: "no-reply.disteleplus@#{Discourse.current_hostname}",
        password: SecureRandom.hex(32),
        active: true,
        approved: true,
        # The bridge channel is TL4-restricted on this forum; TL4 lets the
        # bot post there without also granting staff powers.
        trust_level: TrustLevel[4],
      )
    user.activate
    user
  rescue StandardError => e
    Rails.logger.warn("#{LOG_TAG} bot user create failed: #{e.class}: #{e.message}")
    nil
  end

  # Shared handler for :chat_message_created/_edited/_trashed. Splat args —
  # the chat plugin's event arity is not vendored here, but the message is
  # always the first argument.
  def self.handle_chat_event(event, args)
    return unless SiteSetting.disteleplus_enabled
    return unless chat_available?
    return if ChatAdapter.bridging?

    message = args[0]
    return if message.nil? || !message.respond_to?(:id)

    channel_id = message.try(:chat_channel_id) || args[1].try(:id)
    return unless channel_id == SiteSetting.disteleplus_chat_channel_id

    bot = bot_user
    return if bot && message.user_id == bot.id

    links = MessageLink.for_chat_message(message.id)
    if event == :chat_message_created
      # Already linked → it came FROM Telegram; never echo it back.
      return if links.exists?
    else
      # Edits/trashes of Telegram-originated messages cannot be pushed back —
      # those are the humans' own Telegram messages, untouchable by the bot.
      return if links.tg_to_discourse.exists?
      return if links.empty?
    end

    action =
      {
        chat_message_created: "create",
        chat_message_edited: "edit",
        chat_message_trashed: "delete",
      }[
        event
      ]
    return if action.nil?
    return if action == "edit" && !SiteSetting.disteleplus_bridge_edits
    return if action == "delete" && !SiteSetting.disteleplus_bridge_deletes

    Jobs.enqueue(:disteleplus_send_to_telegram, action: action, chat_message_id: message.id)
  rescue StandardError => e
    Rails.logger.warn("#{LOG_TAG} chat event #{event} failed: #{e.class}: #{e.message}")
  end

  # Handler for a chat reaction event, whatever its exact payload shape —
  # the chat message is found among the args, the reacting user (if present)
  # is used only to skip the bot's own reactions.
  def self.handle_reaction_event(args)
    return unless SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_bridge_reactions
    return unless chat_available?
    return if ChatAdapter.bridging?

    message =
      args.find { |a| a.respond_to?(:chat_channel_id) } ||
        args.filter_map { |a| a.try(:chat_message) || a.try(:message) }.first
    return if message.nil?
    return unless message.try(:chat_channel_id) == SiteSetting.disteleplus_chat_channel_id

    actor = args.find { |a| a.is_a?(::User) }
    bot = bot_user
    return if actor && bot && actor.id == bot.id

    return unless MessageLink.for_chat_message(message.id).exists?

    Jobs.enqueue(:disteleplus_send_to_telegram, action: "react", chat_message_id: message.id)
  rescue StandardError => e
    Rails.logger.warn("#{LOG_TAG} reaction event failed: #{e.class}: #{e.message}")
  end

  # Telegram forum supergroups address their General topic by OMITTING
  # message_thread_id; sending with thread id 1 (General's internal id, which
  # is what an admin reading the URL bar types in) fails with "message thread
  # not found". Normalise both 0 and 1 to "no thread" so a copied id never
  # silently breaks delivery.
  GENERAL_TOPIC_IDS = [0, 1].freeze

  def self.telegram_thread_id(value)
    id = value.to_i
    GENERAL_TOPIC_IDS.include?(id) ? nil : id
  end

  def self.general_topic?(value)
    GENERAL_TOPIC_IDS.include?(value.to_i)
  end

  # The lock's enforcement half: creating channels, DMs and threads is
  # refused for everyone — admins included, no exemption. Admins who need a
  # new channel turn the lock off first; that is the whole point of a lock.
  def self.creation_locked?
    return false unless SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_lock_chat_ui
    # Without a configured channel the client has nowhere to redirect to, so
    # an active lock would strand users in a chat UI that can open nothing.
    return false if SiteSetting.disteleplus_chat_channel_id.to_i.zero?
    true
  end

  # The lock's navigation half: hub pages redirect to the bridge channel.
  # disteleplus_lock_chat_exempt_admins lets admins keep browsing them.
  def self.hub_locked_for?(user)
    return false unless creation_locked?
    return false if SiteSetting.disteleplus_lock_chat_exempt_admins && user&.admin?
    true
  end
end

require_relative "../lib/discourse_disteleplus/emoji_map"
require_relative "../lib/discourse_disteleplus/formatter"
require_relative "../lib/discourse_disteleplus/telegram_api"
require_relative "../lib/discourse_disteleplus/user_matcher"
require_relative "../lib/discourse_disteleplus/chat_adapter"
require_relative "../lib/discourse_disteleplus/setup_command_handler"
require_relative "../lib/discourse_disteleplus/update_processor"
require_relative "../lib/discourse_disteleplus/forum_upload_policy"
require_relative "../lib/discourse_disteleplus/forum_upload_formatter"
require_relative "../lib/discourse_disteleplus/telegram_upload_sender"
require_relative "../lib/discourse_disteleplus/forum_upload_metrics"
require_relative "../lib/discourse_disteleplus/channel_notifications"
require_relative "../lib/discourse_disteleplus/voice_notes"

after_initialize do
  # ── "Register webhook" settings button ────────────────────────────────────
  # Flipping disteleplus_register_webhook_now on auto-generates the webhook
  # secret (if blank), enqueues the setWebhook call, and resets itself —
  # same pattern as dislike's purge_phantom_likes_now.
  on(:site_setting_changed) do |name, _old_val, new_val|
    if name.to_s == "disteleplus_register_webhook_now" && new_val == true
      # Do nothing (not even generate a secret) while the module is off — the
      # job would early-return anyway and the admin would be left with a
      # silently written secret.
      if SiteSetting.disteleplus_enabled
        if SiteSetting.disteleplus_webhook_secret.blank?
          SiteSetting.disteleplus_webhook_secret = SecureRandom.hex(32)
        end
        Jobs.enqueue(:disteleplus_register_webhook)
      end
      SiteSetting.disteleplus_register_webhook_now = false
    elsif name.to_s == "disteleplus_forum_upload_measure_now" && new_val == true
      if SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_forum_uploads_enabled
        Jobs.enqueue(:disteleplus_measure_forum_uploads)
      end
      SiteSetting.disteleplus_forum_upload_measure_now = false
    elsif name.to_s == "disteleplus_forum_upload_backfill_now" && new_val == true
      if SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_forum_uploads_enabled
        Jobs.enqueue(:disteleplus_backfill_forum_uploads, after_reference_id: 0)
      end
      SiteSetting.disteleplus_forum_upload_backfill_now = false
    elsif name.to_s == "disteleplus_setup_commands_enabled" && SiteSetting.disteleplus_enabled
      Jobs.enqueue(:disteleplus_register_webhook)
    elsif name.to_s == "disteleplus_notification_sync_now" && new_val == true
      Jobs.enqueue(:disteleplus_sync_channel_notifications) if SiteSetting.disteleplus_enabled
      SiteSetting.disteleplus_notification_sync_now = false
    elsif %w[
          disteleplus_force_channel_notifications
          disteleplus_chat_channel_id
          disteleplus_enabled
        ].include?(name.to_s)
      # Enrol everyone the moment notifications are forced on (or the
      # channel changes) — not at the next scheduled sync.
      if DiscourseDisteleplus::ChannelNotifications.active?
        Jobs.enqueue(:disteleplus_sync_channel_notifications)
      end
      if DiscourseDisteleplus::VoiceNotes.enabled?
        DiscourseDisteleplus::VoiceNotes.ensure_extensions_authorized!
      end
    elsif name.to_s == "disteleplus_voice_notes_enabled" && new_val == true
      if SiteSetting.disteleplus_enabled
        DiscourseDisteleplus::VoiceNotes.ensure_extensions_authorized!
      end
    end
  end

  # New members get their bridge-channel membership at "always" immediately.
  %i[user_created user_approved user_added_to_group].each do |event|
    on(event) do |first, *_rest|
      next unless DiscourseDisteleplus::ChannelNotifications.active?
      user = first.is_a?(::User) ? first : nil
      next if user.nil?
      Jobs.enqueue_in(5.seconds, :disteleplus_enforce_user_notifications, user_id: user.id)
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} notification #{event} hook failed: #{e.message}",
      )
    end
  end

  # Ordinary forum attachments are an independent one-way archive stream.
  # Delay slightly because UploadReference rows are synchronized as part of
  # post processing and may not yet be visible at the event boundary.
  %i[post_created post_edited].each do |event|
    on(event) do |post, *_args|
      next unless SiteSetting.disteleplus_enabled
      next unless SiteSetting.disteleplus_forum_uploads_enabled
      next unless DiscourseDisteleplus::ForumUploadPolicy.eligible?(post)

      Jobs.enqueue_in(5.seconds, :disteleplus_enqueue_post_uploads, post_id: post.id)
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} forum upload #{event} hook failed: #{e.message}",
      )
    end
  end

  # ── Discourse → Telegram event hooks ──────────────────────────────────────
  %i[chat_message_created chat_message_edited chat_message_trashed].each do |event|
    on(event) { |*args| DiscourseDisteleplus.handle_chat_event(event, args) }
  end

  # Chat fires NO DiscourseEvent for reactions (verified against core:
  # plugins/chat triggers only created/edited/trashed/restored/processed),
  # so Discourse → Telegram reaction bridging observes MessageReactor#react!
  # directly. Fires only after a successful reaction; TG-originated reactions
  # applied through this same reactor are skipped by the bridging? guard in
  # handle_reaction_event. The listener below stays as a freebie in case a
  # future chat version adds the event — double delivery is harmless because
  # the "react" job just re-asserts the current reaction state.
  on(:chat_message_reacted) { |*args| DiscourseDisteleplus.handle_reaction_event(args) }

  reloadable_patch do
    if defined?(::Chat::MessageReactor) && ::Chat::MessageReactor.method_defined?(:react!)
      ::Chat::MessageReactor.prepend(
        Module.new do
          def react!(message_id:, react_action:, emoji:)
            result = super
            begin
              message = ::Chat::Message.find_by(id: message_id)
              user = instance_variable_get(:@user)
              ::DiscourseDisteleplus.handle_reaction_event([message, user].compact) if message
            rescue StandardError => e
              Rails.logger.warn(
                "#{::DiscourseDisteleplus::LOG_TAG} reaction observe failed: #{e.message}",
              )
            end
            result
          end
        end,
      )
    end
  end

  # ── Chat lock: server-side enforcement ────────────────────────────────────
  # The client initializer hides the UI; this makes the restriction real, for
  # admins too. Only methods the installed chat version actually defines are
  # patched, so an upstream rename degrades to "not enforced for that action"
  # instead of a boot error.
  reloadable_patch do
    lock_methods =
      %i[
        can_create_direct_message?
        can_create_chat_channel?
        can_create_channel?
        can_create_thread?
        can_create_chat_thread?
      ].select { |m| ::Guardian.method_defined?(m) }

    if defined?(::Chat) && lock_methods.any?
      ::Guardian.prepend(
        Module.new do
          lock_methods.each do |m|
            define_method(m) do |*args, **kwargs|
              return false if ::DiscourseDisteleplus.creation_locked?
              super(*args, **kwargs)
            end
          end
        end,
      )
    end

    # Threads have no guardian gate of their own — Chat::CreateThread and the
    # implicit reply-creates-thread path both key off the channel's
    # threading_enabled flag. Reporting it as off while locked stops every
    # thread from being born and hides the thread UI in the same stroke.
    # These are ActiveRecord attribute methods, generated lazily on first
    # instantiation — `method_defined?` at boot would say no. Prepend
    # unconditionally and let `defined?(super)` decide at call time.
    if defined?(::Chat::Channel)
      ::Chat::Channel.prepend(
        Module.new do
          %i[threading_enabled threading_enabled?].each do |m|
            define_method(m) do |*args|
              return false if ::DiscourseDisteleplus.creation_locked?
              defined?(super) ? super(*args) : false
            end
          end
        end,
      )
    end
  end

  # ── Forced channel notifications: pin the membership row ──────────────────
  # Any save of a bridge-channel membership (the user lowering their level in
  # channel settings, muting, a bulk update) is snapped back to "always"
  # before it hits the database. Bulk reconciliation lives in the sync job.
  reloadable_patch do
    if defined?(::Chat::UserChatChannelMembership)
      ::Chat::UserChatChannelMembership.class_eval do
        before_save :disteleplus_pin_notification_level

        def disteleplus_pin_notification_level
          return unless ::DiscourseDisteleplus::ChannelNotifications.active?
          unless ::DiscourseDisteleplus::ChannelNotifications.bridge_channel_id?(chat_channel_id)
            return
          end
          return unless following
          ::DiscourseDisteleplus::ChannelNotifications.pin_membership_attributes(self)
        rescue StandardError => e
          Rails.logger.warn(
            "#{::DiscourseDisteleplus::LOG_TAG} membership pin failed: #{e.message}",
          )
        end
      end
    end
  end
end
