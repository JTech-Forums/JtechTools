# frozen_string_literal: true

module DiscourseDisteleplus
  # Database-only preflight. It deliberately does not open upload files or
  # contact Telegram, so an admin can measure a very large archive safely.
  module ForumUploadMetrics
    def self.measure
      eligible_post_ids = ForumUploadPolicy.eligible_scope.select("posts.id")
      refs =
        ::UploadReference
          .where(target_type: "Post", target_id: eligible_post_ids)
          .where.not(upload_id: nil)
      all_post_refs = ::UploadReference.where(target_type: "Post").where.not(upload_id: nil)
      upload_ids = refs.select(:upload_id)
      uploads = ::Upload.where(id: upload_ids)
      limit = [
        SiteSetting.disteleplus_forum_upload_max_mb.megabytes,
        TelegramUploadSender::MAX_SEND_BYTES,
      ].min

      occurrence_bytes =
        ::Upload
          .joins("INNER JOIN upload_references ON upload_references.upload_id = uploads.id")
          .where(upload_references: { target_type: "Post", target_id: eligible_post_ids })
          .sum(:filesize)

      delivered = ForumUploadLink.where(post_id: eligible_post_ids)
      upload_occurrences = refs.count
      all_post_upload_occurrences = all_post_refs.count
      delivered_occurrences = delivered.count

      {
        measured_at: Time.zone.now.iso8601,
        eligible_posts: ::Post.where(id: refs.select(:target_id)).distinct.count,
        all_post_upload_occurrences: all_post_upload_occurrences,
        excluded_occurrences: all_post_upload_occurrences - upload_occurrences,
        upload_occurrences: upload_occurrences,
        unique_uploads: uploads.count,
        unique_upload_hashes: uploads.where.not(sha1: nil).distinct.count(:sha1),
        occurrence_bytes: occurrence_bytes,
        unique_bytes: uploads.sum(:filesize),
        smallest_unique_upload_bytes: uploads.minimum(:filesize),
        largest_unique_upload_bytes: uploads.maximum(:filesize),
        average_unique_upload_bytes: uploads.average(:filesize)&.round,
        over_limit_uploads: uploads.where("filesize > ?", limit).count,
        over_limit_bytes: uploads.where("filesize > ?", limit).sum(:filesize),
        already_delivered_occurrences: delivered_occurrences,
        delivered_file_copies: delivered.where(file_copied: true).count,
        delivered_link_only: delivered.where(file_copied: false).count,
        delivered_unique_hashes: delivered.distinct.count(:upload_sha1),
        remaining_occurrences: [upload_occurrences - delivered_occurrences, 0].max,
        first_upload_post_at:
          ::Post.where(id: refs.select(:target_id)).minimum(:created_at)&.iso8601,
        latest_upload_post_at:
          ::Post.where(id: refs.select(:target_id)).maximum(:created_at)&.iso8601,
        unique_by_extension:
          uploads.group(Arel.sql("COALESCE(NULLIF(extension, ''), '(none)')")).count.sort.to_h,
        unique_bytes_by_extension:
          uploads
            .group(Arel.sql("COALESCE(NULLIF(extension, ''), '(none)')"))
            .sum(:filesize)
            .sort
            .to_h,
      }
    end

    def self.log!
      metrics = measure
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} forum upload measurement: #{metrics.to_json}",
      )
      metrics
    end
  end
end
