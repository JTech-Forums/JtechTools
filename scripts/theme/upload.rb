#!/usr/bin/env ruby
# frozen_string_literal: true

# One-shot sync of themes/jtech to a LOCAL development forum, for working on
# the theme without a rebuild. Production gets the theme from the plugin
# itself (db/fixtures → DiscourseJtechTheme::Installer), never from here.
#
#   JTECH_THEME_URL      forum to sync to (default http://localhost:3000; must be localhost)
#   JTECH_THEME_API_KEY  an admin API key, or JTECH_THEME_API_KEY_FILE pointing at one
#
# Needs the discourse_theme gem (gem install discourse_theme). The first run
# asks which theme to update; pick the "JTech" the plugin installed.
require "discourse_theme"
require "uri"

url = ENV.fetch("JTECH_THEME_URL", "http://localhost:3000")
local = %w[localhost 127.0.0.1].include?(URI(url).host)
abort "refusing: #{url} is not a local forum" unless local

# Plain Ruby: this runs outside Rails, so no ActiveSupport (.presence, .exclude?)
key = ENV["JTECH_THEME_API_KEY"].to_s.strip
key_file = ENV["JTECH_THEME_API_KEY_FILE"].to_s
key = File.read(File.expand_path(key_file)).strip if key.empty? && !key_file.empty?
abort "set JTECH_THEME_API_KEY or JTECH_THEME_API_KEY_FILE" if key.empty?

dir = File.expand_path("../../themes/jtech", __dir__)
ENV["DISCOURSE_URL"] = url
ENV["DISCOURSE_API_KEY"] = key

settings = DiscourseTheme::Config.new(DiscourseTheme::Cli.settings_file)[dir]
client = DiscourseTheme::Client.new(dir, settings, reset: false)
abort "refusing: not #{url}" unless client.url == url

theme_id = settings.theme_id.to_i
theme_id = nil unless theme_id > 0 && client.get_themes_list.any? { |t| t["id"] == theme_id }
id =
  DiscourseTheme::Uploader.new(
    dir: dir,
    client: client,
    theme_id: theme_id,
    components: nil,
  ).upload_full_theme
settings.theme_id = id
puts "JTech theme id #{id} -> #{url}/?preview_theme_id=#{id}"
