# frozen_string_literal: true

module Jobs
  # Registers (or re-registers) this forum's webhook with Telegram. Enqueued
  # by the disteleplus_register_webhook_now settings button; safe to run any
  # number of times — setWebhook is idempotent.
  class DisteleplusRegisterWebhook < ::Jobs::Base
    # Without message_reaction/poll listed explicitly Telegram never delivers
    # those update types at all.
    ALLOWED_UPDATES = %w[message edited_message poll message_reaction].freeze

    def execute(_args)
      return unless SiteSetting.disteleplus_enabled
      if SiteSetting.disteleplus_bot_token.blank? || SiteSetting.disteleplus_webhook_secret.blank?
        Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} setWebhook skipped: token/secret blank")
        return
      end

      result =
        DiscourseDisteleplus::TelegramApi.new.call(
          "setWebhook",
          url: "#{Discourse.base_url}/jtech-disteleplus/telegram/webhook",
          secret_token: SiteSetting.disteleplus_webhook_secret,
          allowed_updates: ALLOWED_UPDATES,
          drop_pending_updates: false,
        )

      if result.ok
        Rails.logger.info("#{DiscourseDisteleplus::LOG_TAG} setWebhook OK")
      else
        Rails.logger.warn(
          "#{DiscourseDisteleplus::LOG_TAG} setWebhook failed: #{result.description}",
        )
      end
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} setWebhook error: #{e.class}: #{e.message}",
      )
    end
  end
end
