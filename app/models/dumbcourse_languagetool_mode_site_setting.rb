# frozen_string_literal: true

require "enum_site_setting"

class DumbcourseLanguagetoolModeSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "Self-hosted", value: "self_hosted" },
      { name: "Official API", value: "official_api" },
    ]
  end
end
