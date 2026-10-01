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
end

require_relative "../lib/discourse_jtech_theme/installer"

# db/fixtures run on every db:migrate (each rebuild, each site), which is when
# core installs its own themes too.
register_seedfu_fixtures(File.expand_path("../db/fixtures", __dir__))
