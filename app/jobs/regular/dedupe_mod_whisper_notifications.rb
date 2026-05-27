# frozen_string_literal: true

module ::Jobs
  # Removes core Discourse notifications (:replied, :posted, :quoted,
  # :mentioned) for users who also received a custom mod_whisper
  # notification for the same post. Scheduled with a small delay from
  # the on(:post_created) hook so PostAlerter has had time to create
  # the duplicates — PostAlerter runs in its own Sidekiq job after
  # :post_created, so an inline cleanup races it.
  #
  # Failure mode: if the job runs before PostAlerter (rare — would mean
  # PostAlerter is slower than 5s), the duplicates haven't been
  # created yet and the delete is a no-op. The duplicates would then
  # stay in the bell. Acceptable degradation; the worst case matches
  # the pre-fix behavior.
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
