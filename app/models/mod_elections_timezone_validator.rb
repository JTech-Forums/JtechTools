# frozen_string_literal: true

# Validates mod_elections_timezone: the election calendar is worked out in
# this zone, so a name Rails doesn't know would stop the schedule.
class ModElectionsTimezoneValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    ActiveSupport::TimeZone[val.to_s].present?
  end

  def error_message
    I18n.t("site_settings.errors.mod_elections_timezone_invalid")
  end
end
