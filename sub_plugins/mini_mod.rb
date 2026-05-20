# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `discourse-mini-mod/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.

require_relative "../lib/discourse_mini_mod/categories_controller_extension"
require_relative "../lib/discourse_mini_mod/guardian_extensions"
require_relative "../lib/discourse_mini_mod/topic_extension"
require_relative "../lib/discourse_mini_mod/topic_view_details_serializer_extension"

# Load the admin JS bundle for category group moderators so they can access
# the category edit/create routes (which live in the admin bundle).
# Security: this only loads client-side route handlers. All actual permissions
# are enforced server-side by Guardian. The admin bundle is a public static
# asset — loading it grants no server-side privileges.
register_html_builder("server:before-head-close") do |controller|
  next "" if controller.blank?
  user = controller.current_user
  next "" if user.blank? || user.staff?
  next "" unless SiteSetting.mini_mod_enabled
  next "" unless SiteSetting.enable_category_group_moderation

  guardian = Guardian.new(user)
  next "" unless guardian.send(:category_group_moderator_scope).exists?

  chunks = EmberCli.script_chunks["chunk.admin"]
  next "" if chunks.blank?

  nonce = controller.helpers.csp_nonce_placeholder
  chunks
    .map do |script_name|
      path = controller.helpers.script_asset_path(script_name)
      %(<link rel="preload" href="#{path}" as="script" nonce="#{nonce}" data-discourse-entrypoint="admin">)
    end
    .join("\n")
end

after_initialize do
  reloadable_patch do
    ::Guardian.prepend(DiscourseMiniMod::GuardianExtensions)
    ::Topic.prepend(DiscourseMiniMod::TopicExtension)
    ::TopicViewDetailsSerializer.prepend(DiscourseMiniMod::TopicViewDetailsSerializerExtension)
    ::CategoriesController.include(DiscourseMiniMod::CategoriesControllerExtension)
  end

  add_to_serializer(:current_user, :can_admin_tags) { scope.can_admin_tags? }

  add_to_serializer(:current_user, :include_can_admin_tags?) do
    SiteSetting.mini_mod_enabled && SiteSetting.mini_mod_manage_tags && SiteSetting.tagging_enabled
  end
end
