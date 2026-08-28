# frozen_string_literal: true

require "enum_site_setting"

# Keep values in sync with the SPA's TOPIC_VIEWS (public/dumbcourse.js) plus
# its separately handled "categories" view. Unknown values silently fall back
# to latest in the SPA.
class DumbcourseDefaultViewSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "admin.site_settings.dumbcourse.view.latest", value: "latest" },
      { name: "admin.site_settings.dumbcourse.view.new", value: "new" },
      { name: "admin.site_settings.dumbcourse.view.top", value: "top" },
      { name: "admin.site_settings.dumbcourse.view.unseen", value: "unseen" },
      { name: "admin.site_settings.dumbcourse.view.hot", value: "hot" },
      { name: "admin.site_settings.dumbcourse.view.my", value: "my" },
      { name: "admin.site_settings.dumbcourse.view.categories", value: "categories" },
    ]
  end

  def self.translate_names?
    true
  end
end
