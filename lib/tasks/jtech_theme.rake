# frozen_string_literal: true

namespace :jtech do
  namespace :theme do
    desc "Install or re-import the JTech theme bundled with Jtech Tools (also after an admin deleted it)"
    task install: :environment do
      installer = DiscourseJtechTheme::Installer
      result =
        DistributedMutex.synchronize(installer::MUTEX_KEY, validity: 5.minutes) do
          installer.reinstall!
        end
      theme = installer.theme
      puts "JTech theme #{result}: id #{theme&.id}"
    end
  end
end
