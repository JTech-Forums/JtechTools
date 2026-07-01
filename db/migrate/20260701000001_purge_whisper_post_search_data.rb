# frozen_string_literal: true

# One-time backfill: strip whisper posts out of `post_search_data`.
#
# Every existing whisper — every row in `post_custom_fields` where
# `name = 'mod_whisper_target_user_ids'` — was originally indexed into
# `post_search_data` before the SearchIndexer gate was in place. That
# tsvector is what leaked whisper text to non-audience users via
# full-text search. This migration deletes those rows in one pass so
# the leak stops on deploy, without waiting for each whisper to be
# re-touched.
#
# `delete_all` bypasses ActiveRecord callbacks — `post_search_data` has
# none we care about, so this is safe and fast. Idempotent: re-running
# just deletes zero rows.
class PurgeWhisperPostSearchData < ActiveRecord::Migration[7.0]
  def up
    execute(<<~SQL)
      DELETE FROM post_search_data
      WHERE post_id IN (
        SELECT post_id
        FROM post_custom_fields
        WHERE name = 'mod_whisper_target_user_ids'
      )
    SQL
  end

  def down
    # Irreversible — the tsvector is derived from posts.raw and would
    # need to be recomputed by SearchIndexer per row, which is out of
    # scope for a migration and would re-introduce the leak.
  end
end
