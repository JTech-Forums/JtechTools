# frozen_string_literal: true

module DiscourseModCategories
  # Apply a whisper-visibility filter to an ActiveRecord Post scope. A post is
  # a whisper when it has a `mod_whisper_target_user_ids` custom field (key
  # PRESENCE marks it — even an empty `[]` array). The returned scope drops
  # any whisper post whose audience does not include the given user.
  #
  # Audience = topic whisper-participants + all staff + post author + the
  # post's explicit user targets + members of any of the post's target
  # groups. Staff bypass the filter entirely. Anonymous viewers see no
  # whispers at all.
  #
  # The same visibility rules as GuardianExtensions#can_see_post? apply — the
  # two must agree (see the parity spec).
  module WhisperQueryFilter
    module_function

    def apply(scope, user)
      return scope unless SiteSetting.mod_whisper_enabled
      return scope if user&.staff?

      field = DiscourseModCategories::POST_WHISPER_TARGETS_FIELD
      join_sql = <<~SQL
        LEFT JOIN post_custom_fields mw_pcf
          ON mw_pcf.post_id = posts.id
          AND mw_pcf.name = '#{field}'
      SQL

      if user
        participant_field = DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD
        groups_field = DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD
        badges_field = DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD
        where_sql = <<~SQL
          mw_pcf.id IS NULL
          OR posts.user_id = :uid
          OR mw_pcf.value::jsonb @> :uid_json::jsonb
          OR EXISTS (
            SELECT 1
            FROM topic_custom_fields mw_tcf
            WHERE mw_tcf.topic_id = posts.topic_id
              AND mw_tcf.name = '#{participant_field}'
              AND mw_tcf.value IS NOT NULL
              AND mw_tcf.value <> ''
              AND mw_tcf.value::jsonb @> :uid_json::jsonb
          )
          OR EXISTS (
            SELECT 1
            FROM post_custom_fields mw_gcf
            JOIN group_users mw_gu
              ON mw_gu.user_id = :uid
              AND mw_gcf.value::jsonb @> to_jsonb(mw_gu.group_id)
            WHERE mw_gcf.post_id = posts.id
              AND mw_gcf.name = '#{groups_field}'
              AND mw_gcf.value IS NOT NULL
              AND mw_gcf.value <> ''
              AND mw_gcf.value <> '[]'
          )
          OR EXISTS (
            SELECT 1
            FROM post_custom_fields mw_bcf
            JOIN user_badges mw_ub
              ON mw_ub.user_id = :uid
              AND mw_bcf.value::jsonb @> to_jsonb(mw_ub.badge_id)
            WHERE mw_bcf.post_id = posts.id
              AND mw_bcf.name = '#{badges_field}'
              AND mw_bcf.value IS NOT NULL
              AND mw_bcf.value <> ''
              AND mw_bcf.value <> '[]'
          )
        SQL

        scope.joins(join_sql).where(where_sql, uid: user.id, uid_json: user.id.to_json)
      else
        scope.joins(join_sql).where("mw_pcf.id IS NULL")
      end
    end
  end
end
