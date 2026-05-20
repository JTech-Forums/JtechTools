# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `dumbcourse/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.

module ::DiscourseDumbcourse
  PLUGIN_NAME = "discourse-dumbcourse"

  def self.base_path
    path = SiteSetting.dumbcourse_base_path.to_s.strip
    path = "dumb" if path.blank?
    path = path.sub(%r{\A/+}, "").sub(%r{/+\z}, "")
    path = "dumb" if path.blank?
    path
  end

  def self.base_path_with_slash
    "/#{base_path}"
  end

  module RequiresPluginFallback
    def requires_plugin(*)
      # no-op for older Discourse versions
    end
  end
end

unless ::ActionController::Base.respond_to?(:requires_plugin)
  ::ActionController::Base.extend(::DiscourseDumbcourse::RequiresPluginFallback)
end

require_relative "../lib/discourse_dumbcourse/engine"
require_relative "../lib/discourse_dumbcourse/push_sender"

after_initialize do
  enabled_site_setting :dumbcourse_enabled

  # Hook: Notification created
  on(:notification_created) do |notification|
    next unless SiteSetting.dumbcourse_push_enabled

    Jobs.enqueue_in(2.seconds, :dumbcourse_push_notify, notification_id: notification.id)
  end

  # Background job for sending push notifications
  module ::Jobs
    class DumbcoursePushNotify < ::Jobs::Base
      def execute(args)
        unless SiteSetting.dumbcourse_push_enabled
          Rails.logger.info(
            "[Dumbcourse Push Job] Push disabled, skipping notification #{args[:notification_id]}",
          )
          return
        end

        notification = Notification.find_by(id: args[:notification_id])
        unless notification
          Rails.logger.warn(
            "[Dumbcourse Push Job] Notification #{args[:notification_id]} not found (deleted?)",
          )
          return
        end

        Rails.logger.info(
          "[Dumbcourse Push Job] Processing notification #{notification.id} type=#{notification.notification_type} user=#{notification.user_id}",
        )
        DiscourseDumbcourse::PushSender.notify_notification(notification)
      end
    end
  end
end
