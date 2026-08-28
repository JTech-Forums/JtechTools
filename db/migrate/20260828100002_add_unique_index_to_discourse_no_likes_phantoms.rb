# frozen_string_literal: true

# The purge job's back-fill relies on ON CONFLICT DO NOTHING, but the table
# only had non-unique indexes — so there was nothing to conflict on and every
# purge run re-inserted the entire audit table. De-duplicate, then add the
# unique index the insert can target.
#
# Discourse's safe-migrate guard requires a possibly-invalid leftover index
# to be dropped before CREATE INDEX CONCURRENTLY, and it recognises the drop
# only through ActiveRecord's remove_index (which registers the index name)
# — a raw DROP INDEX statement does not satisfy it.
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

    remove_index :discourse_no_likes_phantoms,
                 name: "idx_dnl_phantoms_unique_reaction",
                 algorithm: :concurrently,
                 if_exists: true

    add_index :discourse_no_likes_phantoms,
              %i[post_id user_id reaction_type],
              unique: true,
              algorithm: :concurrently,
              name: "idx_dnl_phantoms_unique_reaction"
  end

  def down
    remove_index :discourse_no_likes_phantoms,
                 name: "idx_dnl_phantoms_unique_reaction",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
