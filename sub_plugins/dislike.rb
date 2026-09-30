# frozen_string_literal: true
# Jtech sub-plugin body: Dislike (phantom reactions). Instance_eval'd by
# plugin.rb in the Plugin::Instance context.
#
# In the categories listed in no_reactions_category_ids, likes (and
# discourse-reactions reactions) become "phantom": the post still records
# them, but depending on the settings they
#   - never notify the author and leave no activity-stream rows
#     (dislike_show_in_history off), and/or
#   - don't count toward likes given/received on the user directory and
#     profile (dislike_count_in_leaderboard off).
# Like counts on the posts themselves, badges and trust-level requirements
# are core's and are left alone.

# Shared styling for the maintenance-action buttons on the plugin admin tabs
# (registered here because dislike is the first sub-plugin loaded).
register_asset "stylesheets/jtech-admin.scss"

module ::DiscourseNoLikes
  PLUGIN_NAME = "dislike"

  def self.enabled?
    SiteSetting.jtech_enabled && SiteSetting.discourse_no_likes_enabled
  end

  # Single choke point: every hook and job funnels through this, so the two
  # master switches actually turn the module off.
  def self.restricted_category_ids
    return [] unless enabled?
    SiteSetting.no_reactions_category_ids_map.reject(&:zero?)
  end

  def self.restricted?(post)
    ids = restricted_category_ids
    ids.any? && ids.include?(post&.topic&.category_id)
  end

  def self.restricted_topic_id?(topic_id)
    ids = restricted_category_ids
    ids.any? && Topic.where(id: topic_id, category_id: ids).exists?
  end

  def self.hide_history?
    !SiteSetting.dislike_show_in_history
  end

  def self.count_stats?
    SiteSetting.dislike_count_in_leaderboard
  end

  def self.silence?(post)
    hide_history? && restricted?(post)
  end

  # Mirrors core's own count of user_actions likes (visible, regular posts
  # in visible regular topics) for posts in the restricted categories, and,
  # when phantom likes should count, adds them back straight from
  # post_actions. Applied after core refreshes the directory, so it is
  # authoritative for the directory and for user_stats.likes_*.
  DIRECTORY_ADJUSTMENT_SQL = <<~SQL
    WITH restricted_posts AS (
      SELECT p.id, p.user_id
        FROM posts p
        JOIN topics t ON t.id = p.topic_id
       WHERE t.category_id IN (:category_ids)
         AND t.deleted_at IS NULL
         AND t.visible
         AND t.archetype = 'regular'
         AND p.deleted_at IS NULL
         AND p.post_type = :regular_post_type
         AND NOT p.hidden
    ),
    counts AS (
      SELECT ua.user_id,
             SUM(CASE WHEN ua.action_type = :was_liked_type THEN 1 ELSE 0 END) AS ua_received,
             SUM(CASE WHEN ua.action_type = :like_type THEN 1 ELSE 0 END) AS ua_given,
             0 AS pa_received,
             0 AS pa_given
        FROM user_actions ua
        JOIN restricted_posts rp ON rp.id = ua.target_post_id
       WHERE ua.action_type IN (:like_type, :was_liked_type)
         AND ua.created_at > :since
       GROUP BY ua.user_id
      UNION ALL
      SELECT rp.user_id, 0, 0, COUNT(*), 0
        FROM post_actions pa
        JOIN restricted_posts rp ON rp.id = pa.post_id
       WHERE :count_stats
         AND pa.post_action_type_id = :like_action_type
         AND pa.deleted_at IS NULL
         AND pa.created_at > :since
       GROUP BY rp.user_id
      UNION ALL
      SELECT pa.user_id, 0, 0, 0, COUNT(*)
        FROM post_actions pa
        JOIN restricted_posts rp ON rp.id = pa.post_id
       WHERE :count_stats
         AND pa.post_action_type_id = :like_action_type
         AND pa.deleted_at IS NULL
         AND pa.created_at > :since
       GROUP BY pa.user_id
    ),
    totals AS (
      SELECT user_id,
             SUM(pa_received) - SUM(ua_received) AS received_delta,
             SUM(pa_given) - SUM(ua_given) AS given_delta
        FROM counts
       GROUP BY user_id
    )
    UPDATE directory_items di
       SET likes_received = GREATEST(0, di.likes_received + totals.received_delta),
           likes_given = GREATEST(0, di.likes_given + totals.given_delta)
      FROM totals
     WHERE di.user_id = totals.user_id
       AND di.period_type = :period_type
       AND (totals.received_delta <> 0 OR totals.given_delta <> 0)
  SQL

  def self.adjust_directory!(period_type)
    ids = restricted_category_ids
    return if ids.empty?

    args = DirectoryItem.period_query_args(period_type)
    DB.exec(
      DIRECTORY_ADJUSTMENT_SQL,
      category_ids: ids,
      count_stats: count_stats?,
      like_action_type: PostActionType::LIKE_POST_ACTION_ID,
      since: args[:since],
      period_type: args[:period_type],
      like_type: UserAction::LIKE,
      was_liked_type: UserAction::WAS_LIKED,
      regular_post_type: Post.types[:regular],
    )

    return if period_type != :all

    # Core copied the all-time directory row into user_stats before this
    # ran; copy the corrected like counts again.
    DB.exec(<<~SQL)
      UPDATE user_stats s
         SET likes_given = d.likes_given,
             likes_received = d.likes_received
        FROM directory_items d
       WHERE s.user_id = d.user_id
         AND d.period_type = #{DirectoryItem.period_types[:all]}
         AND (s.likes_given <> d.likes_given OR s.likes_received <> d.likes_received)
    SQL
  end

  def self.record_phantom(post, user_id, reaction_type)
    return unless SiteSetting.dislike_record_audit_trail

    # insert = ON CONFLICT DO NOTHING on the unique index, so re-liking a post
    # (or a race) never raises inside the like request.
    PhantomReaction.insert(
      {
        post_id: post.id,
        user_id: user_id,
        category_id: post.topic.category_id,
        reaction_type: reaction_type,
      },
      unique_by: :idx_dnl_phantoms_unique_reaction,
    )
  end

  module GuardianExtension
    # discourse-reactions delegates to post_can_act?(post, :like), so this
    # covers the reaction picker too.
    def post_can_act?(post, action_key, opts: {}, can_see_post: nil)
      if action_key == :like && DiscourseNoLikes.restricted?(post)
        return false if SiteSetting.dislike_hide_like_button
        allowed = SiteSetting.dislike_allowed_like_groups_map
        return false if allowed.present? && !@user&.in_any_groups?(allowed)
      end
      super
    end
  end

  module UserActionExtension
    def log_action!(hash)
      return super unless phantom_like?(hash)

      if DiscourseNoLikes.hide_history?
        bump_like_stats(hash, 1) if DiscourseNoLikes.count_stats?
        return
      end

      with_like_stats(DiscourseNoLikes.count_stats?) { super }
    end

    # Always goes through core so a history row left from before the
    # category was restricted (or before the setting changed) is removed.
    # Stats move only when phantom likes count, matching log_action!.
    def remove_action!(hash)
      return super unless phantom_like?(hash)
      with_like_stats(DiscourseNoLikes.count_stats?) { super }
    end

    def update_like_count(user_id, action_type, delta)
      return if Thread.current[:dnl_skip_like_stats]
      super
    end

    private

    def phantom_like?(hash)
      [UserAction::LIKE, UserAction::WAS_LIKED].include?(hash[:action_type]) &&
        DiscourseNoLikes.restricted_topic_id?(hash[:target_topic_id])
    end

    def with_like_stats(count)
      previous = Thread.current[:dnl_skip_like_stats]
      Thread.current[:dnl_skip_like_stats] = !count
      yield
    ensure
      Thread.current[:dnl_skip_like_stats] = previous
    end

    # Same columns core's update_like_count moves: LIKE → the liker's
    # likes_given, WAS_LIKED → the author's likes_received.
    def bump_like_stats(hash, delta)
      column = hash[:action_type] == UserAction::LIKE ? "likes_given" : "likes_received"
      UserStat.where(user_id: hash[:user_id]).update_all(
        "#{column} = GREATEST(0, #{column} + (#{delta.to_i}))",
      )
    end
  end

  # Stops the "liked" notification before it exists, instead of deleting it
  # afterwards (by then the bell count and live alert have gone out).
  module PostActionNotifierExtension
    def post_action_created(post_action)
      return if like_on_silenced_post?(post_action)
      super
    end

    # Core would rebuild a "liked" notification listing the remaining likers.
    def post_action_deleted(post_action)
      return if like_on_silenced_post?(post_action)
      super
    end

    private

    def like_on_silenced_post?(post_action)
      post_action.post_action_type_id == PostActionType::LIKE_POST_ACTION_ID &&
        DiscourseNoLikes.silence?(post_action.post)
    end
  end

  module DirectoryItemExtension
    def refresh_period!(period_type, force: false)
      result = super
      DiscourseNoLikes.adjust_directory!(period_type) if SiteSetting.enable_user_directory? || force
      result
    end
  end

  # discourse-reactions sends its own "reacted" notification (its likes are
  # created silently), and rebuilds it when a reaction is removed.
  module ReactionNotificationExtension
    def create
      return if DiscourseNoLikes.silence?(@post)
      super
    end

    def delete
      return if DiscourseNoLikes.silence?(@post)
      super
    end
  end
end

require_relative "../lib/discourse_no_likes/engine"

after_initialize do
  reloadable_patch do
    Guardian.prepend(DiscourseNoLikes::GuardianExtension)
    UserAction.singleton_class.prepend(DiscourseNoLikes::UserActionExtension)
    PostActionNotifier.singleton_class.prepend(DiscourseNoLikes::PostActionNotifierExtension)
    DirectoryItem.singleton_class.prepend(DiscourseNoLikes::DirectoryItemExtension)
    if defined?(DiscourseReactions::ReactionNotification)
      DiscourseReactions::ReactionNotification.prepend(
        DiscourseNoLikes::ReactionNotificationExtension,
      )
    end
  end

  on(:like_created) do |post_action, _creator|
    post = post_action.post
    next unless DiscourseNoLikes.restricted?(post)

    # A reaction that also counts as a like is recorded under its emoji by
    # the ReactionUser callback below; don't log it twice.
    if defined?(DiscourseReactions::ReactionUser) &&
         DiscourseReactions::ReactionUser.exists?(post_id: post.id, user_id: post_action.user_id)
      next
    end

    DiscourseNoLikes.record_phantom(post, post_action.user_id, "like")
  end

  if defined?(DiscourseReactions::ReactionUser)
    add_model_callback("DiscourseReactions::ReactionUser", :after_create) do
      next unless DiscourseNoLikes.restricted?(post)
      value = reaction&.reaction_value.to_s
      next if value.blank? || value == DiscourseReactions::Reaction.main_reaction_id.to_s
      DiscourseNoLikes.record_phantom(post, user_id, value)
    end
  end

  # Legacy run-now toggle, superseded by the Purge button on the Dislike tab.
  on(:site_setting_changed) do |name, _old, new_val|
    if name == :purge_phantom_likes_now && new_val == true
      Jobs.enqueue(:purge_phantom_reactions)
      SiteSetting.purge_phantom_likes_now = false
    end
  end
end
