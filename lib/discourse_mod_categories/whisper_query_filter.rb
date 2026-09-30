# frozen_string_literal: true

module DiscourseModCategories
  # Apply a whisper-visibility filter to an ActiveRecord Post scope. A post is
  # a whisper when it has a `mod_whisper_target_user_ids` custom field (key
  # PRESENCE marks it — even an empty `[]` array). The returned scope drops
  # any whisper post whose audience does not include the given user.
  #
  # Audience = all staff + post author + the post's explicit user targets +
  # current members of the post's target groups + current holders of the
  # post's target badges. Staff bypass the filter entirely. Anonymous viewers
  # see no whispers at all. Enforced regardless of any site setting.
  #
  # The same visibility rules as DiscourseModCategories::Whisper.visible_to?
  # (and so GuardianExtensions#can_see_post?) apply — the two must agree (see
  # the parity specs).
  #
  # EXISTS sub-queries instead of a JOIN: a duplicated custom-field row can't
  # duplicate posts in the stream, and the filter composes with any scope.
  module WhisperQueryFilter
    module_function

    # Parses a custom-field value as a JSON array without ever raising — a
    # malformed legacy value counts as "no targets" (fail closed) instead of
    # 500ing the page.
    def safe_jsonb(column)
      "(CASE WHEN #{column} ~ '^\\s*\\[' THEN #{column}::jsonb ELSE '[]'::jsonb END)"
    end

    def contains_id(column, id_sql)
      json = safe_jsonb(column)
      "(#{json} @> to_jsonb(#{id_sql}) OR #{json} @> to_jsonb((#{id_sql})::text))"
    end

    def is_whisper_sql(posts_table = "posts")
      <<~SQL
        EXISTS (
          SELECT 1 FROM post_custom_fields mw_w
          WHERE mw_w.post_id = #{posts_table}.id AND mw_w.name = '#{DiscourseModCategories::POST_WHISPER_TARGETS_FIELD}'
        )
      SQL
    end

    # SQL predicate (with :mw_uid bind) that is true when the post is not a
    # whisper or the user is in its audience. Staff must be handled by the
    # caller (skip the predicate).
    def visible_sql(posts_table = "posts")
      targets = DiscourseModCategories::POST_WHISPER_TARGETS_FIELD
      groups = DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD
      badges = DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD

      <<~SQL
        (
          NOT #{is_whisper_sql(posts_table)}
          OR #{posts_table}.user_id = :mw_uid
          OR EXISTS (
            SELECT 1 FROM post_custom_fields mw_t
            WHERE mw_t.post_id = #{posts_table}.id
              AND mw_t.name = '#{targets}'
              AND #{contains_id("mw_t.value", ":mw_uid")}
          )
          OR EXISTS (
            SELECT 1
            FROM post_custom_fields mw_g
            JOIN group_users mw_gu
              ON mw_gu.user_id = :mw_uid
              AND #{contains_id("mw_g.value", "mw_gu.group_id")}
            WHERE mw_g.post_id = #{posts_table}.id
              AND mw_g.name = '#{groups}'
          )
          OR EXISTS (
            SELECT 1
            FROM post_custom_fields mw_b
            JOIN user_badges mw_ub
              ON mw_ub.user_id = :mw_uid
              AND #{contains_id("mw_b.value", "mw_ub.badge_id")}
            WHERE mw_b.post_id = #{posts_table}.id
              AND mw_b.name = '#{badges}'
          )
        )
      SQL
    end

    def apply(scope, user, posts_table: "posts")
      user = nil unless user.is_a?(::User)
      return scope if user&.staff?

      if user&.id
        scope.where(visible_sql(posts_table), mw_uid: user.id)
      else
        scope.where("NOT #{is_whisper_sql(posts_table)}")
      end
    end
  end
end
