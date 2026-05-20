# frozen_string_literal: true

module DiscourseMiniMod
  # CategoriesController#create calls `guardian.ensure_can_create!(Category)`
  # without passing the parent category, so the Guardian-level
  # `can_create_category?(parent)` override never sees the actual parent and
  # falls through to the "no parent → allow top-level" branch. Without this
  # extension, a mini-mod could POST /categories.json with parent_category_id
  # pointing at a category they don't moderate and the controller would
  # happily create the subcategory.
  #
  # This adds a per-request check on the create action that re-validates the
  # parent_category_id against the user's category-group-moderator status.
  # The check is a no-op for staff, when the plugin is disabled, when
  # mini_mod_manage_all_categories is on, or when no parent_category_id is
  # supplied.
  module CategoriesControllerExtension
    extend ActiveSupport::Concern

    included { before_action :mini_mod_check_parent_category, only: :create }

    private

    def mini_mod_check_parent_category
      return if !SiteSetting.mini_mod_enabled
      return if !SiteSetting.enable_category_group_moderation
      return if current_user.blank? || current_user.staff?
      return if SiteSetting.mini_mod_manage_all_categories

      parent_id = params[:parent_category_id].presence
      return if parent_id.blank?

      parent = Category.find_by(id: parent_id)
      return if parent.blank?

      unless guardian.is_category_group_moderator?(parent)
        raise Discourse::InvalidAccess.new(
                "Mini-mods can only create subcategories under categories they moderate",
              )
      end
    end
  end
end
