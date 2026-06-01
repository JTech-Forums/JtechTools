# frozen_string_literal: true

# name: jtech-tools
# about: Jtech — combined Discourse plugin (dislike, another-smtp, mini-mod, mod-categories, dumbcourse, translator-tweaks)
# version: 0.1.1
# authors: TripleU, Shalom_Karr, Ars18
# url: https://github.com/JTech-Forums/JtechTools
# required_version: 3.0.0

# Master gate. Each sub-plugin keeps its own enable setting (e.g.
# discourse_no_likes_enabled, mini_mod_enabled, mod_categories_enabled,
# dumbcourse_enabled, discourse_another_email_enabled) for fine-grained control.
enabled_site_setting :jtech_enabled

# Load each sub-plugin's body in the Plugin::Instance context so that all
# Discourse plugin DSL methods — after_initialize, on(:event), register_asset,
# register_svg_icon, add_to_serializer, reloadable_patch, register_html_builder,
# require_relative for nested lib files, etc. — work exactly as they did in the
# original standalone plugin.
#
# Each sub_*.rb file is a faithful copy of its original plugin.rb body
# (magic-header comments and the top-level enabled_site_setting call stripped).
# Settings, locales, lib/, app/, db/migrate, and assets/ from every sub-plugin
# have been merged into this plugin's standard Discourse layout.
%w[
  dislike
  another_smtp
  mini_mod
  mod_categories
  dumbcourse
  translator_tweaks
  smart_search
].each do |sub|
  path = File.expand_path("sub_plugins/#{sub}.rb", __dir__)
  instance_eval(File.read(path), path, 1)
end
