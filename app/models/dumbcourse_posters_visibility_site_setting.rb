# frozen_string_literal: true

require "enum_site_setting"

# Keep values in sync with the SPA's poster-visibility handling
# (public/dumbcourse.js).
class DumbcoursePostersVisibilitySiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "admin.site_settings.dumbcourse.posters.all", value: "all" },
      { name: "admin.site_settings.dumbcourse.posters.desktop", value: "desktop" },
      { name: "admin.site_settings.dumbcourse.posters.mobile", value: "mobile" },
      { name: "admin.site_settings.dumbcourse.posters.none", value: "none" },
    ]
  end

  def self.translate_names?
    true
  end
end
