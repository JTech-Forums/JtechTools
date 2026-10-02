# frozen_string_literal: true
# Jtech sub-plugin: the JTech theme. The theme itself lives in themes/jtech and
# is compiled by core's theme pipeline like any installed theme; this file only
# installs and updates it (see lib/discourse_jtech_theme/installer.rb). Loaded
# by Jtech/plugin.rb in the Plugin::Instance context.

module ::DiscourseJtechTheme
  PLUGIN_NAME = "jtech-theme"

  # Module switch AND the bundle master (jtech_enabled), like every module.
  def self.enabled?
    SiteSetting.jtech_enabled && SiteSetting.jtech_theme_install
  end

  # Per-user icon set for the theme: "lucide" (the theme's outline icons) or
  # "classic" (core's Font Awesome). Absent means lucide.
  ICON_STYLE_FIELD = "jtech_icon_style"
  ICON_STYLES = %w[lucide classic].freeze
end

require_relative "../lib/discourse_jtech_theme/installer"

after_initialize do
  # db/fixtures run on every db:migrate (each rebuild, each site), which is when
  # core installs its own themes too. Registered here rather than at load time:
  # seed-fu's railtie resets SeedFu.fixture_paths after plugins load, which
  # silently dropped the path, so the installer never ran on a rebuild.
  register_seedfu_fixtures(File.expand_path("../db/fixtures", __dir__))

  register_user_custom_field_type(DiscourseJtechTheme::ICON_STYLE_FIELD, :string)
  register_editable_user_custom_field(DiscourseJtechTheme::ICON_STYLE_FIELD)

  add_to_serializer(:current_user, :jtech_icon_style) do
    value = object.custom_fields[DiscourseJtechTheme::ICON_STYLE_FIELD]
    DiscourseJtechTheme::ICON_STYLES.include?(value) ? value : "lucide"
  end

  # Turning the switch on installs now rather than on the next rebuild, and
  # brings back a theme an admin deleted.
  on(:site_setting_changed) do |name, _old_val, new_val|
    if name.to_s == "jtech_theme_install" && new_val == true && SiteSetting.jtech_enabled
      Jobs.enqueue(:jtech_theme_sync)
    end
  end
end
