# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `discourse-mini-mod/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.

require_relative "../lib/discourse_mini_mod/categories_controller_extension"
require_relative "../lib/discourse_mini_mod/guardian_extensions"
require_relative "../lib/discourse_mini_mod/topic_extension"
require_relative "../lib/discourse_mini_mod/topic_view_details_serializer_extension"

# NOTE: the old "preload the admin JS bundle for mini-mods" html builder is
# gone, together with its mini_mod_preload_admin_bundle setting. It called
# EmberCli.script_chunks — a constant that no longer exists in core (replaced
# by EmberAssets) — inside an unrescued builder, which raised NameError on
# every page render for exactly the users it targeted. Even fixed, it could
# not work: the admin bundle is now a staff-gated dynamic import
# (loadAdmin() runs only when data-is-staff="true"), so a preload link
# defines no modules for non-staff.

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
