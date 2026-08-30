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
