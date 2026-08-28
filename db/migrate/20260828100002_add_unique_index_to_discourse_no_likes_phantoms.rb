# frozen_string_literal: true

# The purge job's back-fill relies on ON CONFLICT DO NOTHING, but the table
# only had non-unique indexes — so there was nothing to conflict on and every
# purge run re-inserted the entire audit table. De-duplicate, then add the
# unique index the insert can target.
#
# Discourse's safe-migrate guard requires dropping a possibly-invalid
# leftover index before CREATE INDEX CONCURRENTLY (a failed concurrent build
# leaves an "invalid" index behind), hence the DROP INDEX IF EXISTS first.
class AddUniqueIndexToDiscourseNoLikesPhantoms < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DELETE FROM discourse_no_likes_phantoms a
       USING discourse_no_likes_phantoms b
       WHERE a.id > b.id
         AND a.post_id = b.post_id
         AND a.user_id = b.user_id
         AND a.reaction_type = b.reaction_type
    SQL

    execute "DROP INDEX IF EXISTS idx_dnl_phantoms_unique_reaction"
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY idx_dnl_phantoms_unique_reaction
      ON discourse_no_likes_phantoms (post_id, user_id, reaction_type)
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_dnl_phantoms_unique_reaction"
  end
end
