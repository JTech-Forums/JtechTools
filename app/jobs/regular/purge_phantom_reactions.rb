# frozen_string_literal: true

module Jobs
  # Applies the current Dislike settings to likes that already exist in the
  # restricted categories (the hooks only see likes made from now on).
  class PurgePhantomReactions < ::Jobs::Base
    def execute(_args)
      restricted = DiscourseNoLikes.restricted_category_ids
      return if restricted.empty?

      args = { category_ids: restricted, like_type: PostActionType::LIKE_POST_ACTION_ID }

      # 1. Back-fill the audit table. The ON CONFLICT target is the unique
      # (post_id, user_id, reaction_type) index, so re-running is harmless.
      DB.exec(<<~SQL, args) if SiteSetting.dislike_record_audit_trail
        INSERT INTO discourse_no_likes_phantoms
                    (post_id, user_id, category_id, reaction_type, created_at, updated_at)
        SELECT pa.post_id, pa.user_id, t.category_id, 'like', NOW(), NOW()
          FROM post_actions pa
          JOIN posts p ON p.id = pa.post_id AND p.deleted_at IS NULL
          JOIN topics t ON t.id = p.topic_id AND t.deleted_at IS NULL
         WHERE pa.post_action_type_id = :like_type
           AND pa.deleted_at IS NULL
           AND t.category_id IN (:category_ids)
        ON CONFLICT (post_id, user_id, reaction_type) DO NOTHING
      SQL

      # 2. Hide what the author was already told and what activity streams
      # already show.
      if DiscourseNoLikes.hide_history?
        DB.exec(<<~SQL, args.merge(action_types: [UserAction::LIKE, UserAction::WAS_LIKED]))
          DELETE FROM user_actions ua
           USING topics t
           WHERE t.id = ua.target_topic_id
             AND t.category_id IN (:category_ids)
             AND ua.action_type IN (:action_types)
        SQL

        notification_types = [Notification.types[:liked], Notification.types[:reaction]].compact
        Notification
          .joins(:topic)
          .where(topics: { category_id: restricted })
          .where(notification_type: notification_types)
          .in_batches
          .destroy_all
      end

      # 3. Rebuild likes given/received. The directory refresh reads
      # user_actions (hence after step 2) and DiscourseNoLikes corrects it for
      # the restricted categories, then copies the totals into user_stats.
      DirectoryItem.refresh_period!(:all, force: true)

      Rails.logger.info("[jtech-tools dislike] purge complete")
    end
  end
end
