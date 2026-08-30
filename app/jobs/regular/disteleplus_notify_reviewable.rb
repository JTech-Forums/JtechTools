# frozen_string_literal: true

module Jobs
  # Announces one new Reviewable in the Telegram reports topic with the
  # Approve / Deny / More buttons. Idempotent via the report link table.
  class DisteleplusNotifyReviewable < ::Jobs::Base
    def execute(args)
      return unless DiscourseDisteleplus::Reports.enabled?

      reviewable = Reviewable.find_by(id: args[:reviewable_id])
      DiscourseDisteleplus::Reports.notify_reviewable(reviewable)
    rescue DiscourseDisteleplus::TelegramApi::RateLimited => e
      Jobs.enqueue_in(
        e.retry_after.seconds,
        :disteleplus_notify_reviewable,
        reviewable_id: args[:reviewable_id],
      )
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} reviewable notify failed: #{e.class}: #{e.message}",
      )
    end
  end
end
