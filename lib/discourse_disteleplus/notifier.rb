# frozen_string_literal: true

module DiscourseDisteleplus
  module Notifier
    PATH = "/disteleplus"

    def self.notify(message, actor:)
      return unless SiteSetting.disteleplus_force_channel_notifications

      bot_id = DiscourseDisteleplus.bot_user&.id
      recipients = Access.allowed_users.where.not(id: [actor&.id, bot_id].compact)
      recipients.find_each do |recipient|
        notification =
          Notification.create!(
            notification_type: Notification.types[:custom],
            user_id: recipient.id,
            post_number: message.id,
            high_priority: true,
            data: {
              message: I18n.t("disteleplus.notification", username: display_name(message)),
              title: I18n.t("disteleplus.title"),
              url: PATH,
              username: actor&.username,
              display_username: actor&.username,
              disteleplus_message_id: message.id,
              disteleplus: true,
            }.to_json,
          )
        recipient.publish_notifications_state
        enqueue_push(recipient, message, notification)
      end
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} notification fan-out failed: #{e.message}",
      )
    end

    def self.mark_read(user, through_id)
      marker = '%"disteleplus":true%'
      Notification
        .where(user_id: user.id, notification_type: Notification.types[:custom], read: false)
        .where("post_number <= ?", through_id.to_i)
        .where("data LIKE ?", marker)
        .update_all(read: true)
      user.publish_notifications_state
    end

    # Reuses core PostAlerter.push_notification so we inherit its gate stack:
    # subscription check, do-not-disturb, plugin push filters, the delivery
    # time window and the :push_notification event.
    def self.enqueue_push(user, message, notification)
      return unless defined?(::PostAlerter)

      ::PostAlerter.push_notification(
        user,
        {
          notification_type: notification.notification_type,
          post_number: message.id,
          topic_title: I18n.t("disteleplus.title"),
          excerpt: excerpt(message),
          username: display_name(message),
          post_url: PATH,
        },
      )
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} push enqueue failed: #{e.message}")
    end

    def self.display_name(message)
      message.external_sender_name.presence || message.user&.username || "Telegram"
    end

    def self.excerpt(message)
      return I18n.t("disteleplus.upload_only") if message.raw.blank?

      Post.excerpt(
        message.cooked,
        180,
        text_entities: true,
        strip_links: true,
        remap_emoji: true,
        plain_hashtags: true,
      )
    end
  end
end
