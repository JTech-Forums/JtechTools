# frozen_string_literal: true

module DiscourseMiniMod
  # Every grant here is ADDITIVE on top of core (`return true if super`), and
  # every grant still requires that the category or topic is one the user can
  # see: moderating a category through a group does not grant read access to
  # it, and a mini-mod must never reach a category through this module that
  # core keeps hidden from them.
  module GuardianExtensions
    # Core's controller calls this with no parent, so the answer here only
    # decides whether the "New category" button shows and the request gets
    # past `ensure_can_create!`. CategoriesControllerExtension then checks
    # the actual parent.
    def can_create_category?(parent = nil)
      return true if super
      return false if !mini_mod_can?(:mini_mod_can_create_categories)
      return true if parent.nil?
      mini_mod_reaches_category?(parent)
    end

    def can_edit_category?(category)
      return true if super
      return false if !mini_mod_can?(:mini_mod_can_edit_categories)
      mini_mod_reaches_category?(category)
    end

    def can_edit_serialized_category?(category_id:, read_restricted:)
      return true if super
      return false if !mini_mod_can?(:mini_mod_can_edit_categories)
      return false if !can_see_serialized_category?(category_id:, read_restricted:)
      SiteSetting.mini_mod_manage_all_categories || mini_mod_category_ids.include?(category_id)
    end

    # Mini-mods never delete categories, even though core derives the delete
    # right from the edit right.
    def can_delete_category?(category)
      return false if mini_mod_acting?
      super
    end

    # Site-wide topic editing, with exactly the limits core puts on its own
    # site-wide grant (edit_all_topic_groups): no private messages, no
    # archived topics, no static pages (TOS/FAQ/privacy), and only where they
    # could post.
    def can_edit_topic?(topic)
      return true if super
      return false if !mini_mod_can?(:mini_mod_can_edit_topics)
      return false if !SiteSetting.mini_mod_manage_all_categories
      return false if topic.private_message? || topic.archived
      return false if Discourse.static_doc_topic_ids.include?(topic.id)
      return false if topic.first_post&.locked?
      can_see?(topic) && can_create_post?(topic)
    end

    def can_create_post_on_topic?(topic)
      return false if topic&.closed? && mini_mod_closed_post_restricted?(topic)
      super
    end

    def can_open_topic?(topic)
      return false if topic.present? && mini_mod_reopen_restricted?(topic)
      super
    end

    # Discourse routes both manual close and manual reopen through
    # can_close_topic? (TopicsController#status); on a closed topic the
    # action is a reopen.
    def can_close_topic?(topic)
      return false if topic&.closed? && mini_mod_reopen_restricted?(topic)
      super
    end

    # Core allows any destination the user could start a topic in (moving is
    # gated by can_edit_topic? on the topic itself). Mini-mods may also move
    # topics into categories they moderate even where they couldn't post a
    # new topic, and, with manage-all, past a category's topic approval.
    def can_move_topic_to_category?(category)
      return true if super
      return false if !mini_mod_can?(:mini_mod_can_move_topics)

      category =
        if Category === category
          category
        else
          Category.find_by(id: category || SiteSetting.uncategorized_category_id)
        end
      return false if category.nil? || !can_see_category?(category)
      return true if mini_mod_category_ids.include?(category.id)

      SiteSetting.mini_mod_manage_all_categories && can_create_topic_on_category?(category)
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

    # True for a signed-in, non-staff user whose only route to managing
    # categories is this module.
    def mini_mod_acting?
      DiscourseMiniMod.enabled? && authenticated? && !is_staff? &&
        category_group_moderation_allowed?
    end

    # The categories this user moderates through a group.
    def mini_mod_category_ids
      @mini_mod_category_ids ||= category_group_moderator_scope.pluck(:id).to_set
    end

    # Whether Mini-mod's scope reaches this category: one they moderate, or
    # any category with manage-all — but only ever one they can see.
    def mini_mod_reaches_category?(category)
      return false if category.nil? || !can_see_category?(category)
      SiteSetting.mini_mod_manage_all_categories || mini_mod_category_ids.include?(category.id)
    end

    # A TL4 user or mini-mod who is barred from reopening this topic.
    def mini_mod_reopen_restricted?(topic)
      return false if !DiscourseMiniMod.enabled? || !authenticated? || is_staff?
      return true if !SiteSetting.tl4_can_reopen_topics && user.has_trust_level?(TrustLevel[4])
      !SiteSetting.mini_mod_can_reopen_topics && mini_mod_for?(topic)
    end

    def mini_mod_closed_post_restricted?(topic)
      return false if !DiscourseMiniMod.enabled? || !authenticated? || is_staff?
      if !SiteSetting.tl4_can_post_in_closed_topics && user.has_trust_level?(TrustLevel[4])
        return true
      end
      !SiteSetting.mini_mod_can_post_in_closed_topics && mini_mod_for?(topic)
    end

    private

    def mini_mod_can?(setting)
      mini_mod_acting? && SiteSetting.public_send(setting) && mini_mod_category_ids.any?
    end

    def mini_mod_for?(topic)
      topic.category.present? && is_category_group_moderator?(topic.category)
    end

    def mini_mod_tag_manager?
      mini_mod_can?(:mini_mod_manage_tags) && SiteSetting.tagging_enabled
    end
  end
end
