# frozen_string_literal: true

module Jtech
  # One POST endpoint per maintenance action, driven by real buttons on the
  # /admin/plugins/jtech-tools tabs. These used to be self-resetting checkbox
  # settings ("flip on to run"), which read as configuration; a button says
  # what it is. The legacy *_now settings still work (their
  # site_setting_changed hooks remain) so API/console callers are unaffected.
  class AdminActionsController < ::Admin::AdminController
    requires_plugin "jtech-tools"

    ACTIONS = {
      "register_webhook" => {
        gate: -> { SiteSetting.disteleplus_enabled },
        run: -> do
          if SiteSetting.disteleplus_webhook_secret.blank?
            SiteSetting.disteleplus_webhook_secret = SecureRandom.hex(32)
          end
          Jobs.enqueue(:disteleplus_register_webhook)
        end,
      },
      "send_test_message" => {
        gate: -> { SiteSetting.disteleplus_enabled },
        run: -> { Jobs.enqueue(:disteleplus_send_test_message) },
      },
      "sync_notifications" => {
        gate: -> do
          SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_force_channel_notifications
        end,
        run: -> { Jobs.enqueue(:disteleplus_sync_channel_notifications) },
      },
      "measure_forum_uploads" => {
        gate: -> do
          SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_forum_uploads_enabled
        end,
        run: -> { Jobs.enqueue(:disteleplus_measure_forum_uploads) },
      },
      "backfill_forum_uploads" => {
        gate: -> do
          SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_forum_uploads_enabled
        end,
        run: -> { Jobs.enqueue(:disteleplus_backfill_forum_uploads, after_reference_id: 0) },
      },
      "purge_phantom_likes" => {
        gate: -> { SiteSetting.discourse_no_likes_enabled },
        run: -> { Jobs.enqueue(:purge_phantom_reactions) },
      },
    }.freeze

    def run
      descriptor = ACTIONS[params[:id].to_s]
      raise Discourse::NotFound if descriptor.nil?
      unless descriptor[:gate].call
        return(
          render json: {
                   errors: [I18n.t("jtech_tools.admin_actions.disabled")],
                 },
                 status: :unprocessable_entity
        )
      end

      RateLimiter.new(current_user, "jtech-admin-action", 12, 1.minute).performed!
      descriptor[:run].call
      StaffActionLogger.new(current_user).log_custom(
        "jtech_admin_action",
        { action: params[:id].to_s },
      )
      render json: success_json
    end
  end
end
