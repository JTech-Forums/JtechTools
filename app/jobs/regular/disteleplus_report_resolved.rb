# frozen_string_literal: true

module Jobs
  # Edits the Telegram report message once its Reviewable leaves pending —
  # regardless of whether the resolution came from a Telegram button or the
  # Discourse review queue — so the topic visibly shows who handled it.
  class DisteleplusReportResolved < ::Jobs::Base
    def execute(args)
      return unless DiscourseDisteleplus::Reports.enabled?

      reviewable = Reviewable.find_by(id: args[:reviewable_id])
      return if reviewable.nil?

      DiscourseDisteleplus::Reports.mark_resolved(reviewable, status: args[:status])
    rescue DiscourseDisteleplus::TelegramApi::RateLimited => e
      Jobs.enqueue_in(
        e.retry_after.seconds,
        :disteleplus_report_resolved,
        args.slice(:reviewable_id, :status),
      )
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} report resolve failed: #{e.class}: #{e.message}",
      )
    end
  end
end
