# frozen_string_literal: true

# Review-queue items used to post a "🚩 New review item" line into the
# Disteleplus conversation. Staff already get a bell notification for every
# review item, so the chat line was the same report a second time — and the
# Telegram reports topic carries the actionable copy. The choice is gone from
# disteleplus_event_messages; strip it from stored values so sites that kept
# the old default stop getting the duplicate without touching a setting.
class DropReviewableCreatedFromDisteleplusEventFeed < ActiveRecord::Migration[7.2]
  def up
    execute(<<~SQL)
      UPDATE site_settings
         SET value = trim(BOTH '|' FROM replace('|' || value || '|', '|reviewable_created|', '|')),
             updated_at = NOW()
       WHERE name = 'disteleplus_event_messages'
         AND ('|' || value || '|') LIKE '%|reviewable_created|%'
    SQL

    # disteleplus_event_messages_queued_posts only ever narrowed the
    # review-queue stream this commit removes, so its stored rows are dead.
    execute("DELETE FROM site_settings WHERE name = 'disteleplus_event_messages_queued_posts'")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
