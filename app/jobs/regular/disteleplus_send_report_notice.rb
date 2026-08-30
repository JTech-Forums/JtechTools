# frozen_string_literal: true

module Jobs
  # Delivers one pre-rendered admin notice (dashboard problem, what's-new,
  # official warning issued) into the Telegram reports topic. Deduplication
  # happened before enqueue (Reports.notify_admin_notice).
  class DisteleplusSendReportNotice < ::Jobs::Base
    def execute(args)
      return unless DiscourseDisteleplus::Reports.admin_notices?

      DiscourseDisteleplus::Reports.deliver_notice(args[:html])
    rescue DiscourseDisteleplus::TelegramApi::RateLimited => e
      Jobs.enqueue_in(e.retry_after.seconds, :disteleplus_send_report_notice, html: args[:html])
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} report notice failed: #{e.class}: #{e.message}",
      )
    end
  end
end
