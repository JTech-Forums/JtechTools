# frozen_string_literal: true

# Run via: docker exec app rails runner /var/www/discourse/plugins/jtech-tools/scripts/username_avatar_recalculate.rb
#
# New users get a username-based default avatar automatically once
# discourse_username_avatar_enabled is on. Existing users who already have a
# cached Gravatar-derived avatar keep showing it until it's explicitly
# cleared (Discourse's Gravatar fetch leaves an existing association alone on
# a 404 — it doesn't reset it). This script clears that cached association
# for every user who does NOT have a manually uploaded custom avatar, so they
# fall back to Discourse's username-based letter avatar. It intentionally
# does not delete the underlying Upload rows — only the associations that
# point a user at them — so nothing else referencing those uploads breaks.
# Idempotent — running it again just re-derives the same result.

unless SiteSetting.discourse_username_avatar_enabled
  warn "discourse_username_avatar_enabled is OFF — aborting"
  exit 1
end

affected = 0
skipped_custom = 0

User.includes(:user_avatar).find_each do |user|
  next if user.username.blank?

  ua = user.user_avatar
  next if ua.blank? && user.uploaded_avatar_id.blank?

  # A real custom avatar means uploaded_avatar_id points at something other
  # than the cached Gravatar upload — including the case where there is no
  # user_avatar row at all to compare against (no gravatar_upload_id means
  # nothing here came from update_gravatar!).
  has_real_custom_avatar =
    user.uploaded_avatar_id.present? &&
      (ua.blank? || user.uploaded_avatar_id != ua.gravatar_upload_id)

  if has_real_custom_avatar
    skipped_custom += 1
    next
  end

  User.transaction do
    user.update_columns(uploaded_avatar_id: nil) if user.uploaded_avatar_id.present?
    ua&.update_columns(gravatar_upload_id: nil)
  end

  user.reload
  user.create_user_avatar! if user.user_avatar.blank?

  begin
    user.user_avatar.update_gravatar!
  rescue => e
    Rails.logger.warn("jtech-tools username-avatar: failed to refresh avatar for #{user.username}: #{e.message}")
  end

  affected += 1
end

puts "Reset #{affected} user(s) to the username-based default avatar."
puts "Skipped #{skipped_custom} user(s) with a manually uploaded custom avatar."
