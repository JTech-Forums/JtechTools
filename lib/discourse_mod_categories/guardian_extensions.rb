# frozen_string_literal: true

module DiscourseModCategories
  module GuardianExtensions
    # Each moderator category power carries its own toggle on top of the
    # module master switch, so an admin can see and revoke every grant
    # individually from the plugin settings.
    def can_create_category?(parent = nil)
      return true if super
      mod_categories_grant? && SiteSetting.mod_moderators_can_create_categories
    end

    def can_edit_category?(category)
      return true if super
      mod_categories_grant? && SiteSetting.mod_moderators_can_edit_categories
    end

    def can_edit_serialized_category?(category_id:, read_restricted:)
      return true if super
      mod_categories_grant? && SiteSetting.mod_moderators_can_edit_categories
    end

    def can_delete_category?(category)
      # Core's delete check flows through can_edit_category?, which the
      # module's edit grant satisfies — deferring to super first would let
      # the edit toggle transitively re-grant delete. Check the delete
      # toggle before core gets a say.
      if mod_categories_grant? && !is_admin? && !SiteSetting.mod_moderators_can_delete_categories
        return false
      end
      return true if super
      return false if !mod_categories_grant?
      return false if !SiteSetting.mod_moderators_can_delete_categories
      category.topic_count == 0 && !category.uncategorized? && !category.has_children?
    end

    # Whether the current user may set the plugin's moderator messages
    # (per-topic footer, per-topic reply prompt). Admins always may;
    # moderators may while the plugin is enabled. Regular users never may.
    def can_manage_mod_messages?
      return true if is_admin?
      mod_categories_grant?
    end

    # A whisper post is one that carries the POST_WHISPER_TARGETS_FIELD custom
    # field — KEY PRESENCE marks it, even an empty `[]` array. It is visible
    # only to its audience (staff, the author, its explicit user targets and
    # current members/holders of its target groups/badges); see
    # DiscourseModCategories::Whisper. Enforced regardless of any toggle:
    # switching whispers off must never make existing whispers public.
    def can_see_post?(post)
      if post.is_a?(::Post) &&
           !DiscourseModCategories::Whisper.visible_to?(post, mod_whisper_viewer)
        return false
      end
      super
    end

    # Core has post-level permissions that do NOT route through
    # can_see_post? — e.g. can_view_edit_history? returns true for any
    # post while `edit_history_visible_to_public` is on (the default), and
    # can_edit_post? lets category group moderators / edit_all_post_groups /
    # wiki editors in without a visibility check. Every one of them must be
    # false for a whisper the user cannot see, so no endpoint can hand back
    # a whisper's raw, cooked or revision history as a side effect.
    WHISPER_GATED_POST_PERMISSIONS = %i[
      can_edit_post?
      can_delete_post?
      can_delete_post_or_topic?
      can_permanently_delete_post?
      can_recover_post?
      can_lock_post?
      can_wiki?
      can_view_edit_history?
      can_view_raw_email?
      can_unhide?
      can_receive_post_notifications?
      can_review_post?
    ].freeze

    WHISPER_GATED_POST_PERMISSIONS.each do |name|
      define_method(name) do |post, *args, **kwargs, &blk|
        if post.is_a?(::Post) &&
             !DiscourseModCategories::Whisper.visible_to?(post, mod_whisper_viewer)
          return false
        end
        super(post, *args, **kwargs, &blk)
      end
    end

    def post_can_act?(post, action_key, opts: {}, can_see_post: nil)
      if post.is_a?(::Post) &&
           !DiscourseModCategories::Whisper.visible_to?(post, mod_whisper_viewer)
        return false
      end
      super
    end

    # Revisions of a whisper are as private as the whisper itself.
    def can_see_post_revision?(post_revision)
      post = post_revision&.post
      if post.is_a?(::Post) &&
           !DiscourseModCategories::Whisper.visible_to?(post, mod_whisper_viewer)
        return false
      end
      super
    end

    # Whether the current user may post a whisper in the given topic. Staff
    # always may; a non-staff user may only if they are a recorded whisper
    # participant of the topic (staff whispered to them there before). A
    # non-staff whisper is never wider than the whisper it answers — see the
    # creation logic (Whisper.prepare_new_post!).
    def can_whisper_in_topic?(topic)
      return false unless SiteSetting.mod_whisper_enabled
      return false unless authenticated?
      return true if is_staff?

      mod_whisper_participant_ids(topic).include?(@user.id)
    end

    private

    # Guardian keeps a placeholder AnonymousUser in @user for logged-out
    # viewers; the whisper rules want nil for "nobody".
    def mod_whisper_viewer
      authenticated? ? @user : nil
    end

    def mod_whisper_participant_ids(topic)
      return [] unless topic

      raw = topic.custom_fields[DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD]
      DiscourseModCategories::Whisper.normalize_ids(raw)
    end

    def mod_categories_grant?
      DiscourseModCategories.enabled? && is_moderator?
    end
  end
end
