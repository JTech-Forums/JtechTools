# frozen_string_literal: true
# Jtech sub-plugin: desktop pop-up notifications.
#
# Renders an in-browser "toast" card (top-right, just below the header
# search) when a new notification arrives for the current user — modelled
# on the Jelly macOS notifier's look and delivery. Delivery reuses the
# same MessageBus channel Discourse already publishes notification state
# on (`/notification/:user_id`), so no new server push path is needed.
#
# Desktop only: the frontend never subscribes or renders on mobile
# (`site.mobileView`). Gated per-user by an account-page preference
# ("Desktop Pop Up Notifications", on/off) stored in a user custom field,
# and site-wide by `popup_notifications_enabled`.
#
# The backend here is deliberately thin — the whole experience is
# client-side. All this file does is:
#   * register the per-user boolean custom field + make it editable, and
#   * expose the effective (default-aware) value on the current-user
#     serializer so the client can gate on `currentUser.
#     jtech_popup_notifications_enabled`.

register_asset "stylesheets/popup-notifications.scss"

# Type-badge icons the toast draws on the avatar corner (and the icon-only
# fallback for postless notifications). Registered so they land in the SVG
# sprite; some are core, some are shared with mod-categories.
%w[
  at
  reply
  quote-right
  pencil
  heart
  envelope
  link
  certificate
  check
  xmark
  trash-can
  flag
  eye
  shield-halved
  bell
].each { |name| register_svg_icon(name) }

module ::DiscoursePopupNotifications
  # Per-user preference. Key PRESENCE + value decides; when the field is
  # absent the effective value falls back to
  # `SiteSetting.popup_notifications_default_enabled`.
  USER_ENABLED_FIELD = "jtech_popup_notifications_enabled"
end

after_initialize do
  register_user_custom_field_type(DiscoursePopupNotifications::USER_ENABLED_FIELD, :boolean)

  # Permit the field through UsersController#update so the account-page
  # dropdown can save it with the rest of the preferences form.
  register_editable_user_custom_field(DiscoursePopupNotifications::USER_ENABLED_FIELD)

  # Effective, default-aware preference for the client. Returns the stored
  # boolean when the user has chosen, otherwise the site-wide default.
  add_to_serializer(:current_user, :jtech_popup_notifications_enabled) do
    raw = object.custom_fields[DiscoursePopupNotifications::USER_ENABLED_FIELD]
    if raw.nil?
      SiteSetting.popup_notifications_default_enabled
    else
      ActiveModel::Type::Boolean.new.cast(raw)
    end
  end
end
