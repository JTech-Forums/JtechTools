# frozen_string_literal: true

module DiscourseDisteleplus
  # Receives Telegram Bot API webhook pushes. There is no session here — the
  # X-Telegram-Bot-Api-Secret-Token header (set by our own setWebhook call)
  # IS the authentication, compared in constant time. The controller does the
  # minimum — verify, parse, enqueue — and answers 200 immediately so
  # Telegram's delivery loop never backs up behind Discourse-side work.
  class WebhookController < ::ApplicationController
    requires_plugin "jtech-tools"

    skip_before_action :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       :check_xhr,
                       :preload_json

    def receive
      raise Discourse::NotFound unless SiteSetting.disteleplus_enabled

      secret = SiteSetting.disteleplus_webhook_secret.to_s
      header = request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s
      unless secret.present? && ActiveSupport::SecurityUtils.secure_compare(header, secret)
        return render json: { ok: false }, status: :forbidden
      end

      update =
        begin
          JSON.parse(request.raw_post)
        rescue JSON::ParserError
          nil
        end

      if update.is_a?(Hash) && update["update_id"].present?
        Jobs.enqueue(:disteleplus_process_telegram_update, update: update)
      end

      # Always 200 for authenticated requests — a non-2xx makes Telegram
      # retry the same update in a loop.
      render json: { ok: true }
    end
  end
end
