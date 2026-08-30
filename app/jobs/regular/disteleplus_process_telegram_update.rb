# frozen_string_literal: true

module Jobs
  # Processes one Telegram update off the webhook. All the logic lives in
  # DiscourseDisteleplus::UpdateProcessor; this job only gates, hands off,
  # and re-enqueues itself when Telegram rate-limits a downstream call
  # (getFile during media processing).
  class DisteleplusProcessTelegramUpdate < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.disteleplus_enabled

      update = args[:update]
      return if update.blank?

      DiscourseDisteleplus::UpdateProcessor.new(update.deep_stringify_keys).process
    rescue DiscourseDisteleplus::TelegramApi::RateLimited => e
      Jobs.enqueue_in(e.retry_after.seconds, :disteleplus_process_telegram_update, update: update)
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} inbound update failed: #{e.class}: #{e.message}",
      )
    end
  end
end
