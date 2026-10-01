#!/usr/bin/env ruby
# frozen_string_literal: true

# Live-sync themes/jtech to a LOCAL development forum on every save (the
# discourse_theme CLI). Same variables as upload.rb; never points at a
# non-local forum, since discourse_theme would otherwise upload to whatever URL
# it remembers.
#
#   JTECH_THEME_URL      forum to sync to (default http://localhost:3000; must be localhost)
#   JTECH_THEME_API_KEY  an admin API key, or JTECH_THEME_API_KEY_FILE pointing at one
#
# Extra arguments go to `discourse_theme watch`.
require "uri"

url = ENV.fetch("JTECH_THEME_URL", "http://localhost:3000")
local = %w[localhost 127.0.0.1].include?(URI(url).host)
abort "refusing: #{url} is not a local forum" unless local

# Plain Ruby: this runs outside Rails, so no ActiveSupport (.presence, .exclude?)
key = ENV["JTECH_THEME_API_KEY"].to_s.strip
key_file = ENV["JTECH_THEME_API_KEY_FILE"].to_s
key = File.read(File.expand_path(key_file)).strip if key.empty? && !key_file.empty?
abort "set JTECH_THEME_API_KEY or JTECH_THEME_API_KEY_FILE" if key.empty?

Dir.chdir(File.expand_path("../../themes/jtech", __dir__))
exec({ "DISCOURSE_URL" => url, "DISCOURSE_API_KEY" => key }, "discourse_theme", "watch", ".", *ARGV)
