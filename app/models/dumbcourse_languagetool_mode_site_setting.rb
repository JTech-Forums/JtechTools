# frozen_string_literal: true

require "enum_site_setting"

class DumbcourseLanguagetoolModeSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      {
        name: "admin.site_settings.dumbcourse.languagetool_mode.self_hosted",
        value: "self_hosted",
      },
      {
        name: "admin.site_settings.dumbcourse.languagetool_mode.official_api",
        value: "official_api",
      },
    ]
  end

  def self.translate_names?
    true
  end
end
