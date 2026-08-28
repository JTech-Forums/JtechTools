# frozen_string_literal: true

# Validates dumbcourse_base_path. The route scope is a single dynamic
# segment, so a value containing "/" can never match and silently 404s the
# whole SPA; and core routes are drawn first, so a reserved core prefix
# shadows the SPA the same way. Catch both at save time.
class DumbcourseBasePathValidator
  FORMAT = /\A[a-z0-9][a-z0-9\-_]{0,62}\z/

  RESERVED = %w[
    about
    admin
    assets
    auth
    badges
    c
    categories
    chat
    clicks
    email
    extra-locales
    g
    groups
    hot
    javascripts
    latest
    letter_avatar
    logout
    login
    manifest
    message
    messages
    my
    new
    new-topic
    notifications
    p
    plugins
    posts
    presence
    pub
    review
    safe-mode
    search
    session
    signup
    site
    srv
    stylesheets
    t
    tag
    tags
    top
    topics
    u
    unread
    uploads
    user-api-key
    users
    webhooks
    wizard
  ].freeze

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    v = val.to_s.strip.downcase
    return true if v.blank? # falls back to "dumb"
    return false unless v.match?(FORMAT)
    !RESERVED.include?(v)
  end

  def error_message
    I18n.t("site_settings.errors.dumbcourse_base_path_invalid")
  end
end
