# frozen_string_literal: true

module DiscourseMiniMod
  module GuardianExtensions
    def can_create_category?(parent = nil)
      return true if super
      return false if !SiteSetting.mini_mod_enabled
      return false if !category_group_moderation_allowed?
      return false if !category_group_moderator_scope.exists?

      return true if SiteSetting.mini_mod_manage_all_categories

      if parent
        is_category_group_moderator?(parent)
      else
        true
      end
    end

    def can_edit_category?(category)
      return true if super
      return false if !SiteSetting.mini_mod_enabled

      if SiteSetting.mini_mod_manage_all_categories
        category_group_moderation_allowed? && category_group_moderator_scope.exists?
      else
        is_category_group_moderator?(category)
      end
    end

    def can_edit_serialized_category?(category_id:, read_restricted:)
      return true if super
      return false if !SiteSetting.mini_mod_enabled
      return false if !category_group_moderation_allowed?

      if SiteSetting.mini_mod_manage_all_categories
        category_group_moderator_scope.exists?
      else
        category_group_moderator_scope.where(id: category_id).exists?
      end
    end

    def can_edit_topic?(topic)
      return true if super
      return false if !SiteSetting.mini_mod_enabled
      return false if !SiteSetting.mini_mod_manage_all_categories
      return false if !category_group_moderation_allowed?
      return false if !category_group_moderator_scope.exists?
      can_see?(topic) && !topic.first_post&.locked?
    end

    def can_create_post_on_topic?(topic)
      if SiteSetting.mini_mod_enabled && !SiteSetting.tl4_can_post_in_closed_topics &&
           topic.present? && topic.closed? && !is_staff? && @user.has_trust_level?(TrustLevel[4])
        return false
      end
      if SiteSetting.mini_mod_enabled && !SiteSetting.mini_mod_can_post_in_closed_topics &&
           topic.present? && topic.closed? && !is_staff? && mini_mod_for?(topic)
        return false
      end
      super
    end

    def can_open_topic?(topic)
      if SiteSetting.mini_mod_enabled && !SiteSetting.tl4_can_reopen_topics &&
           topic.present? && !is_staff? && @user.has_trust_level?(TrustLevel[4])
        return false
      end
      if SiteSetting.mini_mod_enabled && !SiteSetting.mini_mod_can_reopen_topics &&
           topic.present? && !is_staff? && mini_mod_for?(topic)
        return false
      end
      super
    end

    # Discourse routes both manual close and manual reopen through `can_close_topic?`
    # (TopicsController#status -> ensure_can_close_topic!). The toggle direction is
    # inferred from the topic's current state, so we block this Guardian check only
    # when the topic is already closed — in that case, the action is a reopen, which
    # we want to revoke from category group moderators by default.
    def can_close_topic?(topic)
      if SiteSetting.mini_mod_enabled && !SiteSetting.tl4_can_reopen_topics &&
           topic.present? && topic.closed? && !is_staff? && @user.has_trust_level?(TrustLevel[4])
        return false
      end
      if SiteSetting.mini_mod_enabled && !SiteSetting.mini_mod_can_reopen_topics &&
           topic.present? && topic.closed? && !is_staff? && mini_mod_for?(topic)
        return false
      end
      super
    end

    def can_move_topic_to_category?(category)
      return true if super
      return false if !SiteSetting.mini_mod_enabled
      return false if !category_group_moderation_allowed?

      category =
        if Category === category
          category
        else
          Category.find(category || SiteSetting.uncategorized_category_id)
        end

      if SiteSetting.mini_mod_manage_all_categories
        category_group_moderator_scope.exists? && can_see_category?(category)
      else
        is_category_group_moderator?(category)
      end
    end

    def can_admin_tags?
      return true if super
      mini_mod_tag_manager?
    end

    def can_create_tag?
      return true if super
      mini_mod_tag_manager?
    end

    def can_edit_tag_names?
      return true if super
      mini_mod_tag_manager?
    end

    private

    # True when the current user is a category group moderator for the given
    # topic's category. Used by the closed-topic restrictions to scope them to
    # actual mini-mods rather than to every non-staff user core would otherwise
    # treat as trusted (e.g. trust level 4).
    def mini_mod_for?(topic)
      topic.category.present? && is_category_group_moderator?(topic.category)
    end

    def mini_mod_tag_manager?
      SiteSetting.mini_mod_enabled && SiteSetting.mini_mod_manage_tags &&
        SiteSetting.tagging_enabled && category_group_moderation_allowed? &&
        category_group_moderator_scope.exists?
    end
  end
end
