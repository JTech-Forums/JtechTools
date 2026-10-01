# frozen_string_literal: true

module ::DiscourseJtechTheme
  # Installs the JTech theme bundled in themes/jtech, the way core installs its
  # own themes (db/fixtures/600_themes.rb → RemoteTheme.import_theme_from_directory).
  # It runs on every db:migrate, so a plugin update brings the theme up to date.
  #
  # It only ever installs or updates. Making JTech the default, letting users
  # pick it and attaching components stay admin decisions. If an admin deletes
  # the theme it stays deleted; `rake jtech:theme:install` brings it back.
  module Installer
    STORE_KEY = "bundled_theme"

    def self.directory
      ENV["JTECH_THEME_DIR"].presence || File.expand_path("../../themes/jtech", __dir__)
    end

    # SHA256 over every file's relative path and bytes: updates are skipped
    # unless the bundled theme actually changed.
    def self.digest(dir = directory)
      sha = Digest::SHA256.new
      Dir
        .glob("**/*", base: dir)
        .sort
        .each do |path|
          full = File.join(dir, path)
          next if File.directory?(full)
          sha << path << "\0" << File.binread(full) << "\0"
        end
      sha.hexdigest
    end

    def self.state
      PluginStore.get(PLUGIN_NAME, STORE_KEY) || {}
    end

    def self.save_state(state)
      PluginStore.set(PLUGIN_NAME, STORE_KEY, state)
    end

    def self.theme
      id = state["theme_id"]
      id && Theme.find_by(id: id)
    end

    # Called from db/fixtures on every migrate. Never raises: a theme that
    # fails to import must not stop a rebuild.
    def self.sync!
      return :skipped_test if Rails.env.test? && ENV["JTECH_THEME_SEED"].blank?
      return :disabled if !DiscourseJtechTheme.enabled?

      DistributedMutex.synchronize("jtech_bundled_theme", validity: 5.minutes) { sync_now }
    rescue => e
      Rails.logger.error("[jtech-tools] JTech theme install failed: #{e.class}: #{e.message}")
      warn "[jtech-tools] JTech theme install failed: #{e.class}: #{e.message}"
      :failed
    end

    def self.sync_now
      current = state
      bundled = digest

      if current["theme_id"]
        return :removed if current["removed_at"]

        if !Theme.exists?(id: current["theme_id"])
          save_state(current.merge("removed_at" => Time.zone.now.iso8601))
          return :removed
        end

        return :unchanged if current["digest"] == bundled
      end

      install(theme_id: current["theme_id"], digest: bundled)
    end

    # Brings the theme back after an admin deleted it (or forces a re-import).
    def self.reinstall!
      current = state
      id = current["theme_id"] if current["theme_id"] && Theme.exists?(id: current["theme_id"])
      install(theme_id: id, digest: digest)
    end

    def self.install(theme_id:, digest:)
      theme =
        RemoteTheme.import_theme_from_directory(
          directory,
          theme_id: theme_id,
          allow_out_of_sequence_migration: theme_id.present?,
        )
      save_state("theme_id" => theme.id, "digest" => digest)
      Stylesheet::Manager.clear_theme_cache!
      theme_id ? :updated : :installed
    end
  end
end
