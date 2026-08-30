# frozen_string_literal: true

module DiscourseModCategories
  # Which notification types this user actually has — the type filter on the
  # notifications page shows only these instead of every type Discourse has
  # ever defined.
  class NotificationTypesController < ::ApplicationController
    requires_plugin "jtech-tools"
    requires_login

    def index
      raise Discourse::NotFound unless SiteSetting.mod_categories_enabled
      raise Discourse::NotFound unless SiteSetting.mod_notification_type_filter_enabled

      ids = Notification.where(user_id: current_user.id).distinct.pluck(:notification_type)
      names = Notification.types.filter_map { |name, id| name if ids.include?(id) }
      mod_notes =
        current_user.staff? &&
          Notification
            .where(user_id: current_user.id, notification_type: Notification.types[:custom])
            .where("data LIKE ?", '%"mod_note"%')
            .exists?
      render_json_dump({ types: names, mod_notes: mod_notes })
    end
  end
end
