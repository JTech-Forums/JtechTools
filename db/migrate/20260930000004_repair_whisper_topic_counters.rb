# frozen_string_literal: true

# Topics whose whispers were written before whispers stopped raising
# highest_post_number still count them as new posts for everyone. Recompute
# the public counters (as DiscourseModCategories::Whisper.
# refresh_topic_counters does for every new whisper) for each topic that has
# a whisper.
class RepairWhisperTopicCounters < ActiveRecord::Migration[7.2]
  PUBLIC_POSTS = <<~SQL
    p.deleted_at IS NULL
    AND p.post_type NOT IN (3, 4)
    AND NOT EXISTS (
      SELECT 1 FROM post_custom_fields w
       WHERE w.post_id = p.id AND w.name = 'mod_whisper_target_user_ids'
    )
  SQL

  def up
    execute <<~SQL
      UPDATE topics t
         SET highest_post_number = GREATEST(COALESCE((
               SELECT MAX(p.post_number) FROM posts p
                WHERE p.topic_id = t.id AND #{PUBLIC_POSTS}
             ), 0), 1),
             posts_count = (
               SELECT COUNT(*) FROM posts p WHERE p.topic_id = t.id AND #{PUBLIC_POSTS}
             )
       WHERE t.id IN (
         SELECT DISTINCT p.topic_id
           FROM posts p
           JOIN post_custom_fields f ON f.post_id = p.id
          WHERE f.name = 'mod_whisper_target_user_ids'
       )
    SQL
  end

  def down
  end
end
