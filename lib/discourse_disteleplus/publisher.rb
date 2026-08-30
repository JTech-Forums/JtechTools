# frozen_string_literal: true

module DiscourseDisteleplus
  module Publisher
    CHANNEL = "/disteleplus/conversation"
    TYPING_CHANNEL = "/disteleplus/typing"

    def self.publish_typing(user)
      user_ids =
        Access
          .allowed_users
          .where.not(id: [user.id, DiscourseDisteleplus.bot_user&.id].compact)
          .pluck(:id)
      return if user_ids.empty?
      MessageBus.publish(
        TYPING_CHANNEL,
        { user_id: user.id, username: user.username, name: user.name },
        user_ids: user_ids,
        max_backlog_age: 5,
      )
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} typing publish failed: #{e.message}")
    end

    # Read-cursor advance for "Seen by". Throttled per user: a fast scroll
    # advances the cursor many times a second, one event every few seconds
    # is plenty for a receipt chip.
    def self.publish_read_state(user, last_read_message_id)
      return unless SiteSetting.disteleplus_read_receipts_enabled
      throttle_key = "disteleplus:read-pub:#{user.id}"
      return unless Discourse.redis.set(throttle_key, "1", ex: 3, nx: true)

      user_ids =
        Access
          .allowed_users
          .where.not(id: [user.id, DiscourseDisteleplus.bot_user&.id].compact)
          .pluck(:id)
      return if user_ids.empty?
      MessageBus.publish(
        CHANNEL,
        {
          type: "read",
          user_id: user.id,
          username: user.username,
          name: user.name,
          avatar_template: user.avatar_template,
          last_read_message_id: last_read_message_id,
          updated_at: Time.zone.now.iso8601,
        },
        user_ids: user_ids,
        max_backlog_age: 5,
      )
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} read publish failed: #{e.message}")
    end

    # A voice note was played for the first time by this user — the sender's
    # "listened" receipt. One-shot per user+message, so no throttle needed.
    def self.publish_listen(message, listener)
      return unless SiteSetting.disteleplus_read_receipts_enabled

      user_ids =
        Access
          .allowed_users
          .where.not(id: [listener.id, DiscourseDisteleplus.bot_user&.id].compact)
          .pluck(:id)
      return if user_ids.empty?
      MessageBus.publish(
        CHANNEL,
        {
          type: "listened",
          message_id: message.id,
          user_id: listener.id,
          username: listener.username,
          name: listener.name,
          avatar_template: listener.avatar_template,
        },
        user_ids: user_ids,
        max_backlog_age: 5,
      )
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} listen publish failed: #{e.message}")
    end

    def self.publish(event, message, actor: nil)
      user_ids = Access.allowed_users.where.not(id: DiscourseDisteleplus.bot_user&.id).pluck(:id)
      return if user_ids.empty?

      MessageBus.publish(
        CHANNEL,
        {
          type: event.to_s,
          actor_id: actor&.id,
          message: MessageSerializer.serialize(message, viewer: nil),
        },
        user_ids: user_ids,
        max_backlog_size: 100,
      )
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} realtime publish failed: #{e.message}")
    end
  end
end
