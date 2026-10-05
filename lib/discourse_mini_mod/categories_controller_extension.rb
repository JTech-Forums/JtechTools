# frozen_string_literal: true

module DiscourseMiniMod
  # CategoriesController trusts anyone who passes `ensure_can_edit!` /
  # `ensure_can_create!` with every category field, because core only lets
  # staff through. Mini-mods get through too, so their requests are narrowed
  # here:
  #
  # * Fields that decide who can see, moderate or mail into a category, or
  #   that carry plugin data, are dropped (the category form sends every
  #   field on save, so they are ignored rather than rejected). Otherwise a
  #   mini-mod could make a private category public, or hand moderation — and
  #   with it every Mini-mod right — to any group, trust_level_0 included.
  # * A new category must sit under a category they moderate (anywhere they
  #   can see with manage-all), and inherits that parent's access and
  #   moderators, so they can manage what they create and it is no more
  #   visible than its parent.
  # * Moving a category to another parent is held to the same rule.
  # * Reordering categories site-wide stays with staff.
  module CategoriesControllerExtension
    extend ActiveSupport::Concern

    STAFF_ONLY_PARAMS = %i[
      permissions
      moderating_group_ids
      email_in
      email_in_allow_strangers
      mailinglist_mirror
      custom_fields
      topic_posting_review_group_ids
      reply_posting_review_group_ids
      category_type
      category_types
      category_type_settings
      category_type_site_settings
      position
    ].freeze

    included do
      before_action :mini_mod_narrow_create, only: :create
      before_action :mini_mod_narrow_update, only: :update
      before_action :mini_mod_forbid_reorder, only: %i[move reorder]
    end

    private

    # Non-staff, so any category right they have came from this module.
    def mini_mod_request?
      current_user.present? && guardian.mini_mod_acting?
    end

    def mini_mod_narrow_create
      return if !mini_mod_request?

      mini_mod_strip_staff_params
      parent = Category.find_by(id: params[:parent_category_id].presence)

      if parent.nil?
        raise Discourse::InvalidAccess unless SiteSetting.mini_mod_manage_all_categories
        return
      end
      raise Discourse::InvalidAccess unless guardian.mini_mod_reaches_category?(parent)

      params[:permissions] = parent.permissions_params.presence || { "everyone" => 1 }
      params[:moderating_group_ids] = parent.moderating_group_ids
    end

    def mini_mod_narrow_update
      return if !mini_mod_request?

      mini_mod_strip_staff_params
      # Core's fetch_category (which runs first) finds the category by its
      # slug as well as its id. Looking it up by id alone missed
      # PUT /categories/<slug>.json and skipped the stripping above.
      category =
        @category || Category.find_by_slug(params[:id]) || Category.find_by(id: params[:id].to_i)
      return if category.nil? || !params.key?(:parent_category_id)

      new_parent_id = params[:parent_category_id].presence&.to_i
      return if new_parent_id == category.parent_category_id

      if new_parent_id.nil?
        raise Discourse::InvalidAccess unless SiteSetting.mini_mod_manage_all_categories
      else
        new_parent = Category.find_by(id: new_parent_id)
        raise Discourse::InvalidAccess unless guardian.mini_mod_reaches_category?(new_parent)
      end
    end

    def mini_mod_forbid_reorder
      raise Discourse::InvalidAccess if mini_mod_request?
    end

    def mini_mod_strip_staff_params
      STAFF_ONLY_PARAMS.each { |key| params.delete(key) }
      if (settings = params[:category_setting_attributes]).respond_to?(:delete)
        # The review modes pair with the review group lists above, which stay
        # with staff; require_topic/reply_approval stay with the moderator.
        settings.delete(:topic_posting_review_mode)
        settings.delete(:reply_posting_review_mode)
      end
    end
  end
end
