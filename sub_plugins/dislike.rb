# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `Dislike/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.

# [Jtech] removed top-level: enabled_site_setting :discourse_no_likes_enabled

module ::DiscourseNoLikes
  PLUGIN_NAME = "dislike"

  # SQL: count real likes received by a user, excluding restricted categories
  LIKES_RECEIVED_SQL = <<~SQL.freeze
    SELECT COUNT(*)
      FROM post_actions  pa
      JOIN posts         p  ON p.id  = pa.post_id   AND p.deleted_at IS NULL
      JOIN topics        t  ON t.id  = p.topic_id   AND t.deleted_at IS NULL
     WHERE p.user_id              = %{uid}
       AND pa.post_action_type_id = %{like_type}
       AND pa.deleted_at          IS NULL
       AND t.category_id NOT IN (%{restricted})
  SQL

  # SQL: count real likes given by a user, excluding restricted categories
  LIKES_GIVEN_SQL = <<~SQL.freeze
    SELECT COUNT(*)
      FROM post_actions  pa
      JOIN posts         p  ON p.id  = pa.post_id   AND p.deleted_at IS NULL
      JOIN topics        t  ON t.id  = p.topic_id   AND t.deleted_at IS NULL
     WHERE pa.user_id             = %{uid}
       AND pa.post_action_type_id = %{like_type}
       AND pa.deleted_at          IS NULL
       AND t.category_id NOT IN (%{restricted})
  SQL

  def self.restricted_category_ids
    SiteSetting.no_reactions_category_ids.to_s.split("|").map(&:to_i).reject(&:zero?)
  end

  def self.restricted?(post)
    ids = restricted_category_ids
    ids.any? && ids.include?(post&.topic&.category_id)
  end
end

require_relative "../lib/discourse_no_likes/engine"

after_initialize do
  # ── Guardian override: hide button + group gate ────────────────────────────
  # - dislike_hide_like_button=true → button hidden, backend rejects
  # - dislike_allowed_like_groups set → only members can see/click
  # discourse-reactions delegates to post_can_act?(post, :like) so it's covered
  Guardian.prepend(
    Module.new do
      def post_can_act?(post, action_key, opts: {}, can_see_post: nil)
        if action_key == :like && DiscourseNoLikes.restricted?(post)
          return false if SiteSetting.dislike_hide_like_button
          allowed = SiteSetting.dislike_allowed_like_groups
          if allowed.present? && @user.present?
            return false unless @user.in_any_groups?(SiteSetting.dislike_allowed_like_groups_map)
          end
        end
        super
      end
    end,
  )

  # ── UserAction.log_action! — conditional based on settings ─────────────────
  # For a phantom like in a restricted category:
  #   show_in_history=true  AND count_in_leaderboard=true  → call super (normal)
  #   show_in_history=true  AND count_in_leaderboard=false → call super, skip stats
  #   show_in_history=false AND count_in_leaderboard=true  → skip super, update stats directly
  #   show_in_history=false AND count_in_leaderboard=false → skip entirely (original behavior)
  UserAction.singleton_class.prepend(
    Module.new do
      def log_action!(hash)
        if [UserAction::LIKE, UserAction::WAS_LIKED].include?(hash[:action_type])
          restricted = DiscourseNoLikes.restricted_category_ids
          if restricted.any?
            topic = Topic.find_by(id: hash[:target_topic_id])
            if topic && restricted.include?(topic.category_id)
              show_hist = SiteSetting.dislike_show_in_history
              count_stats = SiteSetting.dislike_count_in_leaderboard

              if show_hist && count_stats
                # Normal behavior — both history and stats
                return super(hash)
              elsif show_hist && !count_stats
                # History yes, stats no — set thread-local flag to skip update_like_count
                Thread.current[:dnl_skip_stats] = true
                begin
                  return super(hash)
                ensure
                  Thread.current[:dnl_skip_stats] = nil
                end
              elsif !show_hist && count_stats
                # No history, but update stats directly
                _dnl_update_stats_only(hash)
                return
              else
                # Fully phantom — skip everything (original behavior)
                return
              end
            end
          end
        end
        super(hash)
      end

      def update_like_count(user_id, action_type, delta)
        return if Thread.current[:dnl_skip_stats]
        super
      end

      def remove_action!(hash)
        if [UserAction::LIKE, UserAction::WAS_LIKED].include?(hash[:action_type])
          restricted = DiscourseNoLikes.restricted_category_ids
          if restricted.any?
            topic = Topic.find_by(id: hash[:target_topic_id])
            if topic && restricted.include?(topic.category_id)
              show_hist = SiteSetting.dislike_show_in_history
              count_stats = SiteSetting.dislike_count_in_leaderboard

              if show_hist && count_stats
                return super(hash)
              elsif show_hist && !count_stats
                Thread.current[:dnl_skip_stats] = true
                begin
                  return super(hash)
                ensure
                  Thread.current[:dnl_skip_stats] = nil
                end
              elsif !show_hist && count_stats
                _dnl_update_stats_only(hash, delta: -1)
                return
              else
                return
              end
            end
          end
        end
        super(hash)
      end

      private

      def _dnl_update_stats_only(hash, delta: 1)
        # Mirror Discourse's update_like_count exactly:
        #   LIKE      → hash[:user_id] is the liker   → likes_given
        #   WAS_LIKED → hash[:user_id] is the author  → likes_received
        if hash[:action_type] == UserAction::LIKE
          UserStat.where(user_id: hash[:user_id]).update_all(
            "likes_given = GREATEST(0, likes_given + (#{delta}))",
          )
        elsif hash[:action_type] == UserAction::WAS_LIKED
          UserStat.where(user_id: hash[:user_id]).update_all(
            "likes_received = GREATEST(0, likes_received + (#{delta}))",
          )
        end
      end
    end,
  )

  # ── Audit trail + suppress "liked" notification ───────────────────────────
  on(:post_action_created) do |post_action|
    next unless post_action.post_action_type_id == PostActionType.types[:like]
    next unless (post = post_action.post)
    next unless DiscourseNoLikes.restricted?(post)

    DiscourseNoLikes::PhantomReaction.create!(
      post_id: post.id,
      user_id: post_action.user_id,
      category_id: post.topic.category_id,
      reaction_type: "like",
    )

    # Only suppress notification if history is disabled
    unless SiteSetting.dislike_show_in_history
      Notification
        .where(
          user_id: post.user_id,
          notification_type: Notification.types[:liked],
          topic_id: post.topic_id,
          post_number: post.post_number,
        )
        .where("created_at >= ?", 30.seconds.ago)
        .destroy_all
    end
  end

  # ── discourse-reactions: record non-heart emoji reactions ─────────────────
  if defined?(DiscourseReactions::ReactionUser)
    DiscourseReactions::ReactionUser.class_eval do
      after_create :dnl_record_phantom_emoji

      private

      def dnl_record_phantom_emoji
        return unless DiscourseNoLikes.restricted?(post)
        main_id =
          (
            begin
              DiscourseReactions::Reaction.main_reaction_id.to_s
            rescue StandardError
              "heart"
            end
          )
        rv = reaction&.reaction_value.to_s
        return if rv == main_id

        DiscourseNoLikes::PhantomReaction.create!(
          post_id: post_id,
          user_id: user_id,
          category_id: post.topic.category_id,
          reaction_type: rv,
        )
      end
    end
  end

  # ── Retroactive purge trigger ─────────────────────────────────────────────
  on(:site_setting_changed) do |name, _old, new_val|
    if name == :purge_phantom_likes_now && new_val == true
      Jobs.enqueue(:purge_phantom_reactions)
      SiteSetting.purge_phantom_likes_now = false
    end
  end
end
