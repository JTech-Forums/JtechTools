# frozen_string_literal: true

module Jobs
  # Resumable ascending-ID scan. It schedules small batches rather than one
  # giant job, keeping normal Sidekiq work responsive during a large archive.
  class DisteleplusBackfillForumUploads < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.disteleplus_enabled
      return unless SiteSetting.disteleplus_forum_uploads_enabled

      cursor = args[:after_reference_id].to_i
      batch_number = args[:batch_number].to_i
      totals = {
        scanned: args[:scanned].to_i,
        queued: args[:queued].to_i,
        ineligible: args[:ineligible].to_i,
        already_delivered: args[:already_delivered].to_i,
      }
      DiscourseDisteleplus::ForumUploadMetrics.log! if cursor.zero?

      references =
        ::UploadReference
          .where(target_type: "Post")
          .where("upload_references.id > ?", cursor)
          .includes(:upload, target: %i[topic user])
          .order("upload_references.id ASC")
          .limit(SiteSetting.disteleplus_forum_upload_backfill_batch_size)
          .to_a

      if references.empty?
        Rails.logger.warn(
          "#{DiscourseDisteleplus::LOG_TAG} forum upload backfill scan complete; " \
            "delivery jobs may still be running: #{totals.to_json}; " \
            "current delivery state: #{DiscourseDisteleplus::ForumUploadMetrics.measure.to_json}",
        )
        return
      end

      queued_this_batch = 0
      spacing_seconds = SiteSetting.disteleplus_forum_upload_backfill_spacing_seconds

      references.each do |reference|
        totals[:scanned] += 1
        post = reference.target
        upload = reference.upload
        unless upload && DiscourseDisteleplus::ForumUploadPolicy.eligible?(post)
          totals[:ineligible] += 1
          next
        end
        if DiscourseDisteleplus::ForumUploadLink.exists?(post_id: post.id, upload_id: upload.id)
          totals[:already_delivered] += 1
          next
        end
        Jobs.enqueue_in(
          (queued_this_batch * spacing_seconds).seconds,
          :disteleplus_send_forum_upload,
          post_id: post.id,
          upload_id: upload.id,
        )
        queued_this_batch += 1
        totals[:queued] += 1
      end

      if (batch_number % 10).zero?
        Rails.logger.warn(
          "#{DiscourseDisteleplus::LOG_TAG} forum upload backfill progress: " \
            "#{totals.merge(after_reference_id: references.last.id).to_json}",
        )
      end

      continuation_delay_seconds =
        [
          SiteSetting.disteleplus_forum_upload_backfill_pause_seconds,
          queued_this_batch * spacing_seconds,
        ].max
      Jobs.enqueue_in(
        continuation_delay_seconds.seconds,
        :disteleplus_backfill_forum_uploads,
        after_reference_id: references.last.id,
        batch_number: batch_number + 1,
        **totals,
      )
    end
  end
end
