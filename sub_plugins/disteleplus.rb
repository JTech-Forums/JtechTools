# frozen_string_literal: true

# Jtech sub-plugin: Disteleplus — Telegram ⇄ native Discourse conversation.
#
# Disteleplus owns its messages, uploads, reactions, unread state, API,
# realtime channel, notifications and UI. The official Discourse Chat plugin
# is not required. An isolated optional importer can read a legacy Chat
# channel during migration, but normal operation never touches Chat models,
# services, routes, memberships, events, or frontend APIs.

register_asset "stylesheets/disteleplus.scss"
register_asset "stylesheets/disteleplus-native.scss"

# Icons drawn by the header shortcut, conversation, context menu, composer and
# voice recorder. Discourse ships only a subset of FontAwesome in its sprite;
# an unregistered icon renders as an empty <svg>.
%w[
  arrow-down
  comments
  copy
  download
  ellipsis
  face-smile
  file
  link
  microphone
  paperclip
  paper-plane
  pencil
  play
  plus
  quote-right
  reply
  rotate
  spinner
  stop
  trash-can
  upload
  xmark
].each { |name| register_svg_icon(name) }

module ::DiscourseDisteleplus
  LOG_TAG = "[jtech-tools disteleplus]"
  GENERAL_TOPIC_IDS = [0, 1].freeze

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
        trust_level: TrustLevel[4],
      )
    user.activate
    user
  rescue StandardError => e
    Rails.logger.warn("#{LOG_TAG} bot user create failed: #{e.class}: #{e.message}")
    nil
  end

  def self.telegram_thread_id(value)
    id = value.to_i
    GENERAL_TOPIC_IDS.include?(id) ? nil : id
  end

  def self.general_topic?(value)
    GENERAL_TOPIC_IDS.include?(value.to_i)
  end
end

require_relative "../lib/discourse_disteleplus/emoji_map"
require_relative "../lib/discourse_disteleplus/formatter"
require_relative "../lib/discourse_disteleplus/telegram_api"
require_relative "../lib/discourse_disteleplus/user_matcher"
require_relative "../lib/discourse_disteleplus/access"
require_relative "../lib/discourse_disteleplus/message_serializer"
require_relative "../lib/discourse_disteleplus/publisher"
require_relative "../lib/discourse_disteleplus/notifier"
require_relative "../lib/discourse_disteleplus/message_service"
require_relative "../lib/discourse_disteleplus/setup_command_handler"
require_relative "../lib/discourse_disteleplus/update_processor"
require_relative "../lib/discourse_disteleplus/forum_upload_policy"
require_relative "../lib/discourse_disteleplus/forum_upload_formatter"
require_relative "../lib/discourse_disteleplus/telegram_upload_sender"
require_relative "../lib/discourse_disteleplus/forum_upload_metrics"
require_relative "../lib/discourse_disteleplus/channel_notifications"
require_relative "../lib/discourse_disteleplus/voice_notes"
require_relative "../lib/discourse_disteleplus/legacy_chat_importer"
require_relative "../lib/discourse_disteleplus/health"
require_relative "../lib/discourse_disteleplus/forum_post_notifier"

after_initialize do
  # Serializer classes only exist once the app has booted.
  add_to_serializer(:current_user, :can_access_disteleplus) do
    ::DiscourseDisteleplus::Access.allowed?(object)
  end

  on(:site_setting_changed) do |name, _old_val, new_val|
    case name.to_s
    when "disteleplus_register_webhook_now"
      if new_val == true
        if SiteSetting.disteleplus_enabled
          if SiteSetting.disteleplus_webhook_secret.blank?
            SiteSetting.disteleplus_webhook_secret = SecureRandom.hex(32)
          end
          Jobs.enqueue(:disteleplus_register_webhook)
        end
        SiteSetting.disteleplus_register_webhook_now = false
      end
    when "disteleplus_forum_upload_measure_now"
      if new_val == true
        if SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_forum_uploads_enabled
          Jobs.enqueue(:disteleplus_measure_forum_uploads)
        end
        SiteSetting.disteleplus_forum_upload_measure_now = false
      end
    when "disteleplus_forum_upload_backfill_now"
      if new_val == true
        if SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_forum_uploads_enabled
          Jobs.enqueue(:disteleplus_backfill_forum_uploads, after_reference_id: 0)
        end
        SiteSetting.disteleplus_forum_upload_backfill_now = false
      end
    when "disteleplus_send_test_message_now"
      if new_val == true
        Jobs.enqueue(:disteleplus_send_test_message) if SiteSetting.disteleplus_enabled
        SiteSetting.disteleplus_send_test_message_now = false
      end
    when "disteleplus_setup_commands_enabled"
      Jobs.enqueue(:disteleplus_register_webhook) if SiteSetting.disteleplus_enabled
    when "disteleplus_notification_sync_now"
      if new_val == true
        Jobs.enqueue(:disteleplus_sync_channel_notifications) if SiteSetting.disteleplus_enabled
        SiteSetting.disteleplus_notification_sync_now = false
      end
    when "disteleplus_force_channel_notifications", "disteleplus_allowed_groups",
         "disteleplus_enabled"
      if DiscourseDisteleplus::ChannelNotifications.active?
        Jobs.enqueue(:disteleplus_sync_channel_notifications)
      end
      if DiscourseDisteleplus::VoiceNotes.enabled?
        DiscourseDisteleplus::VoiceNotes.ensure_extensions_authorized!
      end
    when "disteleplus_voice_notes_enabled"
      if new_val == true && SiteSetting.disteleplus_enabled
        DiscourseDisteleplus::VoiceNotes.ensure_extensions_authorized!
      end
    end
  end

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

  on(:post_created) do |post, *_args|
    next unless DiscourseDisteleplus::ForumPostNotifier.eligible?(post)
    Jobs.enqueue_in(10.seconds, :disteleplus_notify_forum_post, post_id: post.id)
  rescue StandardError => e
    Rails.logger.warn(
      "#{DiscourseDisteleplus::LOG_TAG} forum post notify hook failed: #{e.message}",
    )
  end

  register_problem_check ::ProblemCheck::DisteleplusTelegram if respond_to?(:register_problem_check)

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

  reloadable_patch do
    ::Guardian.prepend(
      Module.new do
        def can_access_disteleplus?
          ::DiscourseDisteleplus::Access.allowed?(user)
        end

        def can_moderate_disteleplus?
          ::DiscourseDisteleplus::Access.moderator?(user)
        end
      end,
    )
  end
end
