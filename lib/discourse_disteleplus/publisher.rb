# frozen_string_literal: true

module DiscourseDisteleplus
  module Publisher
    CHANNEL = "/disteleplus/conversation"

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
