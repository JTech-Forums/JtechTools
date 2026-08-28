# frozen_string_literal: true

# Converts the legacy pipe-delimited `disteleplus_user_mappings` list
# ("tg_name:discourse_name|...") into the `type: objects` setting
# `disteleplus_user_map`, which the admin UI edits with a proper table
# editor.
#
# A NEW NAME is used deliberately. Changing `type:` on the existing name
# would leave the DB row at data_type 8 (list) while the yml says 28
# (objects); the admin site-settings endpoint then 500s, because core's
# hydrate_objects_setting_value JSON-parses the value with no rescue, and
# the pipe string is not JSON.
#
# ON CONFLICT DO NOTHING makes this idempotent and stops it clobbering an
# admin who already edited the new setting.
class MigrateDisteleplusUserMappingsToObjects < ActiveRecord::Migration[7.2]
  # SiteSettings::TypeSupervisor.types[:objects] — inlined, migrations must
  # not depend on app constants that may move.
  OBJECTS_DATA_TYPE = 28

  def up
    old =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'disteleplus_user_mappings' LIMIT 1",
      ).first
    return if old.blank?

    rows =
      old
        .to_s
        .split("|")
        .filter_map do |pair|
          tg, dc = pair.split(":", 2)
          tg = tg.to_s.strip.delete_prefix("@")
          dc = dc.to_s.strip.delete_prefix("@")
          next if tg.blank? || dc.blank?
          { "telegram_username" => tg, "discourse_username" => dc }
        end
    return if rows.empty?

    DB.exec(<<~SQL, value: rows.to_json, data_type: OBJECTS_DATA_TYPE)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('disteleplus_user_map', :data_type, :value, NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    DB.exec("DELETE FROM site_settings WHERE name = 'disteleplus_user_map'")
  end
end
