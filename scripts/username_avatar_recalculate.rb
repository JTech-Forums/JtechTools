# frozen_string_literal: true

# Run via: docker exec app rails runner /var/www/discourse/plugins/jtech-tools/scripts/username_avatar_recalculate.rb
#
# Switches everyone who currently shows a Gravatar picture back to their
# letter avatar (which is based on their username). Uploaded custom avatars
# are left alone, and so are the system user and bots (ids below 1), which
# use Gravatar on purpose.
#
# Run it after turning off automatically_download_gravatars (and, to take
# the choice away, gravatar_enabled) — otherwise Discourse fetches the
# Gravatar pictures again. Goes through User#save, so quoted posts showing
# the old picture are queued for a rebake. Safe to run again.

if SiteSetting.automatically_download_gravatars
  warn "automatically_download_gravatars is on — turn it off first, or the pictures come back."
  exit 1
end

reset = 0

User
  .human_users
  .joins(:user_avatar)
  .where("users.uploaded_avatar_id = user_avatars.gravatar_upload_id")
  .find_each do |user|
    user.update!(uploaded_avatar_id: nil)
    reset += 1
  rescue StandardError => e
    warn "Couldn't reset #{user.username}: #{e.message}"
  end

puts "Switched #{reset} user(s) from their Gravatar picture to their letter avatar."
