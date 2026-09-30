# frozen_string_literal: true

# The Mod module's mod_moderators_can_{create,edit,delete}_categories grants
# are replaced by core's moderators_manage_categories, which does the same
# but only for categories the moderator can see. Sites where the grant was in
# effect (module on, grant not switched off) get the core setting switched
# on, so moderators keep managing categories; the old rows are removed.
class MoveModeratorCategoryGrantsToCore < ActiveRecord::Migration[7.2]
  OLD = %w[
    mod_moderators_can_create_categories
    mod_moderators_can_edit_categories
    mod_moderators_can_delete_categories
  ].freeze

  def up
    stored =
      DB
        .query(<<~SQL, names: OLD + %w[jtech_enabled mod_categories_enabled])
      SELECT name, value FROM site_settings WHERE name IN (:names)
    SQL
        .to_h { |r| [r.name, r.value] }

    on = ->(name) { stored[name] != "f" } # every one of these defaulted to true
    granted =
      on.("jtech_enabled") && on.("mod_categories_enabled") &&
        (on.("mod_moderators_can_create_categories") || on.("mod_moderators_can_edit_categories"))

    # A brand-new site never relied on the old grant; it starts with core's
    # default.
    execute <<~SQL if granted && Migration::Helpers.existing_site?
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('moderators_manage_categories', 5, 't', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL

    execute "DELETE FROM site_settings WHERE name IN (#{OLD.map { |n| "'#{n}'" }.join(", ")})"
  end

  def down
  end
end
