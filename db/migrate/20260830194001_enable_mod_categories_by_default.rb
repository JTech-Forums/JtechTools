# frozen_string_literal: true

# The mod-categories master toggle used to default OFF, which silently hid
# pinned-bottom posts and the shield notifications feed on deployed sites —
# their own toggles default on but ride on the master. The default is now
# on; clearing any stored "off" rows lets the new default govern everywhere
# (an admin can still turn any of them off again afterwards).
class EnableModCategoriesByDefault < ActiveRecord::Migration[7.2]
  SETTINGS = %w[mod_categories_enabled mod_pin_post_enabled mod_notes_feed_enabled]

  def up
    execute(<<~SQL)
      DELETE FROM site_settings
      WHERE name IN (#{SETTINGS.map { |name| "'#{name}'" }.join(", ")})
        AND value = 'f'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
