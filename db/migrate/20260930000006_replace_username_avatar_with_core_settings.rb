# frozen_string_literal: true

# The Username avatar module (discourse_username_avatar_enabled) is gone. It
# made every Gravatar lookup miss on purpose, so nobody got a Gravatar
# picture. Core does the same directly: automatically_download_gravatars off
# stops the lookups and gravatar_enabled off removes the Gravatar choice
# (which the module had broken anyway). Existing sites that had the module
# on get both switched off.
class ReplaceUsernameAvatarWithCoreSettings < ActiveRecord::Migration[7.2]
  def up
    stored = DB.query(<<~SQL).to_h { |r| [r.name, r.value] }
        SELECT name, value FROM site_settings
         WHERE name IN ('jtech_enabled', 'discourse_username_avatar_enabled')
      SQL

    # Both defaulted to on.
    was_on = stored["jtech_enabled"] != "f" && stored["discourse_username_avatar_enabled"] != "f"

    if was_on && Migration::Helpers.existing_site?
      %w[automatically_download_gravatars gravatar_enabled].each { |name| execute <<~SQL }
          INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
          VALUES ('#{name}', 5, 'f', NOW(), NOW())
          ON CONFLICT (name) DO NOTHING
        SQL
    end

    execute "DELETE FROM site_settings WHERE name = 'discourse_username_avatar_enabled'"
  end

  def down
  end
end
