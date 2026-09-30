# frozen_string_literal: true

require "enum_site_setting"

# How hard REQ-PM asks users who have no contact details yet to add some.
# Semantics live in DiscourseReqpm::Setup.
class ReqpmSetupPromptSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "admin.site_settings.reqpm.setup_prompt.off", value: "off" },
      { name: "admin.site_settings.reqpm.setup_prompt.gentle", value: "gentle" },
      { name: "admin.site_settings.reqpm.setup_prompt.required", value: "required" },
    ]
  end

  def self.translate_names?
    true
  end
end
