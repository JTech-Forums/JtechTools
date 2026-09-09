# frozen_string_literal: true

module Jobs
  # Creates the Telegram "Reports" forum topic when none is stored yet.
  # Enqueued on boot (self-migrating deploys) and whenever reports are turned
  # on; idempotent — Reports.ensure_topic! returns early once a topic exists.
  class DisteleplusEnsureReportsTopic < ::Jobs::Base
    def execute(_args)
      return unless DiscourseDisteleplus::Reports.enabled?
      DiscourseDisteleplus::Reports.ensure_topic!
    rescue DiscourseDisteleplus::TelegramApi::RateLimited => e
      Jobs.enqueue_in(e.retry_after.seconds, :disteleplus_ensure_reports_topic)
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} ensure reports topic failed: #{e.class}: #{e.message}",
      )
    end
  end
end
