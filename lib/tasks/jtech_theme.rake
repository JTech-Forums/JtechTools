# frozen_string_literal: true

namespace :jtech do
  namespace :theme do
    desc "Install or re-import the JTech theme bundled with Jtech Tools (also after an admin deleted it)"
    task install: :environment do
      result = DiscourseJtechTheme::Installer.reinstall!
      theme = DiscourseJtechTheme::Installer.theme
      puts "JTech theme #{result}: id #{theme&.id}"
    end
  end
end
