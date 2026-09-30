# frozen_string_literal: true

module ::Jobs
  # No longer enqueued: whisper recipients are now kept out of PostAlerter
  # up front (the :post_alerter_before_mentions hook in
  # sub_plugins/mod_categories.rb). Kept so jobs queued before the upgrade
  # still run; safe to delete in a later release.
  #
  # Removes core notifications (:replied, :posted, :quoted, :mentioned) for
  # users who also received a custom mod_whisper notification for the post.
  class DedupeModWhisperNotifications < ::Jobs::Base
    def execute(args)
      post_id = args[:post_id]
      recipient_ids = Array(args[:recipient_ids]).map(&:to_i).reject(&:zero?)
      return if post_id.blank? || recipient_ids.empty?

      post = ::Post.find_by(id: post_id)
      return unless post

      removed =
        ::Notification.where(
          user_id: recipient_ids,
          topic_id: post.topic_id,
          post_number: post.post_number,
          notification_type: [
            ::Notification.types[:replied],
            ::Notification.types[:posted],
            ::Notification.types[:quoted],
            ::Notification.types[:mentioned],
          ],
        ).delete_all

      return if removed.zero?

      # Refresh the bell counts for each affected user so the badge in
      # the header reflects the decreased unread total without waiting
      # for the next /session/current poll.
      ::User.where(id: recipient_ids).find_each(&:publish_notifications_state)
    end
  end
end
