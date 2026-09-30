# frozen_string_literal: true

# dislike_notification_cleanup_window_seconds is gone: the "liked"
# notification is now never created, instead of being deleted afterwards.
class DropDislikeNotificationCleanupWindow < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'dislike_notification_cleanup_window_seconds'"
  end

  def down
  end
end
