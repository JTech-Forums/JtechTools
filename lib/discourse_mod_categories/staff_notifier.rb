# frozen_string_literal: true

module ::DiscourseModCategories
  # Shared fan-out of high-priority custom Notifications + live MessageBus
  # alerts to every other staff member. Used for the three "staff event"
  # streams that are NOT topic-attached private notes:
  #   - actions on a post (delete / approve queued / reject queued)
  #   - notes added on a user's profile (discourse-user-notes)
  #   - notes added to a flag / reviewable in the review queue
  #
  # The notification carries the same `mod_note: true` marker the topic-
  # note flow uses, so the existing client renderer
  # (assets/javascripts/discourse/lib/mod-note-notification.js) and the
  # shield-tab unread counter pick these up alongside topic notes. The
  # `mod_note_kind` field tells the renderer which label/title to show.
  module StaffNotifier
    KIND_POST_DELETED = "post_deleted"
    KIND_POST_APPROVED = "post_approved"
    KIND_POST_REJECTED = "post_rejected"
    KIND_USER_NOTE = "user_note"
    KIND_FLAG_NOTE = "flag_note"

    # `acting_user` is excluded from recipients so the moderator who
    # performed the action does not get their own notification.
    def self.fan_out(
      acting_user:,
      kind:,
      message_key:,
      title_key:,
      alert_key:,
      url:,
      excerpt: nil,
      topic_id: nil,
      post_number: nil,
      topic_title: nil,
      target_username: nil
    )
      return if acting_user.blank?

      acting_username = acting_user.username
      truncated_excerpt = excerpt.to_s.truncate(300)

      ::User
        .where(admin: true)
        .or(::User.where(moderator: true))
        .where.not(id: acting_user.id)
        .find_each do |staff_user|
          data = {
            display_username: acting_username,
            mod_note: true,
            mod_note_kind: kind,
            excerpt: truncated_excerpt,
            url: url,
            message: message_key,
            title: title_key,
          }
          data[:topic_title] = topic_title if topic_title.present?
          data[:target_username] = target_username if target_username.present?

          ::Notification.create!(
            notification_type: ::Notification.types[:custom],
            user_id: staff_user.id,
            topic_id: topic_id,
            post_number: post_number,
            high_priority: true,
            data: data.to_json,
          )

          publish_alert(
            staff_user,
            alert_key: alert_key,
            url: url,
            excerpt: truncated_excerpt,
            username: acting_username,
            topic_id: topic_id,
            post_number: post_number,
            topic_title: topic_title,
            target_username: target_username,
          )
          staff_user.publish_notifications_state
        end
    end

    def self.publish_alert(
      staff_user,
      alert_key:,
      url:,
      excerpt:,
      username:,
      topic_id:,
      post_number:,
      topic_title:,
      target_username:
    )
      return if staff_user.suspended?
      return unless staff_user.allow_live_notifications?

      i18n_args = { username: username }
      i18n_args[:topic] = topic_title if topic_title.present?
      i18n_args[:target] = target_username if target_username.present?

      payload = {
        notification_type: ::Notification.types[:custom],
        topic_id: topic_id,
        post_number: post_number,
        excerpt: excerpt,
        username: username,
        post_url: url,
        translated_title: ::I18n.t(alert_key, **i18n_args),
      }
      payload[:topic_title] = topic_title if topic_title.present?

      ::MessageBus.publish(
        "/notification-alert/#{staff_user.id}",
        payload,
        user_ids: [staff_user.id],
      )
    end
  end
end
