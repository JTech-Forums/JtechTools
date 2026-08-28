# frozen_string_literal: true

module Jobs
  # Delivers one attachment occurrence. The distributed mutex closes the race
  # between a historical scan and the live post hook.
  class DisteleplusSendForumUpload < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.disteleplus_enabled
      return unless SiteSetting.disteleplus_forum_uploads_enabled

      post_id = args[:post_id].to_i
      upload_id = args[:upload_id].to_i
      return if post_id.zero? || upload_id.zero?

      DistributedMutex.synchronize("disteleplus_forum_upload_#{post_id}_#{upload_id}") do
        deliver(post_id, upload_id)
      end
    rescue DiscourseDisteleplus::TelegramApi::RateLimited => e
      Jobs.enqueue_in(
        e.retry_after.seconds,
        :disteleplus_send_forum_upload,
        post_id: args[:post_id],
        upload_id: args[:upload_id],
      )
    end

    private

    def deliver(post_id, upload_id)
      delivered =
        DiscourseDisteleplus::ForumUploadLink.exists?(post_id: post_id, upload_id: upload_id)
      return if delivered

      post = ::Post.includes(:user, :uploads, topic: :category).find_by(id: post_id)
      return unless DiscourseDisteleplus::ForumUploadPolicy.eligible?(post)

      # Re-check the association, not merely Upload.exists?: edits can detach
      # an upload before this queued job runs.
      upload = post.uploads.find { |candidate| candidate.id == upload_id }
      return if upload.nil?

      chat_id = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      topic_id = SiteSetting.disteleplus_forum_upload_topic_id.to_i
      return if chat_id.blank? || topic_id.zero?
      if topic_id == SiteSetting.disteleplus_chat_topic_id.to_i
        Rails.logger.warn(
          "#{DiscourseDisteleplus::LOG_TAG} forum upload topic must differ from chat topic",
        )
        return
      end

      delivery =
        DiscourseDisteleplus::TelegramUploadSender.new.send(
          upload: upload,
          caption: DiscourseDisteleplus::ForumUploadFormatter.caption(post, upload),
          chat_id: chat_id,
          topic_id: topic_id,
          max_bytes: SiteSetting.disteleplus_forum_upload_max_mb.megabytes,
        )

      DiscourseDisteleplus::ForumUploadLink.create!(
        post_id: post.id,
        upload_id: upload.id,
        telegram_chat_id: chat_id,
        telegram_message_id: delivery.message.fetch("message_id"),
        telegram_topic_id: topic_id,
        upload_sha1: upload.sha1,
        file_copied: delivery.file_copied,
      )
    rescue ActiveRecord::RecordNotUnique
      # Another worker won after Telegram returned. The mutex normally makes
      # this unreachable, but the unique index remains the final guard.
      nil
    end
  end
end
