# frozen_string_literal: true

module Jobs
  # Runs when an admin turns jtech_theme_install on, so the theme is installed
  # (or a deleted one brought back) without waiting for the next rebuild.
  class JtechThemeSync < ::Jobs::Base
    def execute(_args)
      return if !DiscourseJtechTheme.enabled?

      DistributedMutex.synchronize(
        DiscourseJtechTheme::Installer::MUTEX_KEY,
        validity: 5.minutes,
      ) { DiscourseJtechTheme::Installer.restore! }
    end
  end
end
