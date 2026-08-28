# frozen_string_literal: true

module Jobs
  # Resolves current UploadReference rows after create/edit post-processing.
  class DisteleplusEnqueuePostUploads < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.disteleplus_enabled
      return unless SiteSetting.disteleplus_forum_uploads_enabled

      post = ::Post.includes(:topic, :uploads).find_by(id: args[:post_id])
      return unless DiscourseDisteleplus::ForumUploadPolicy.eligible?(post)

      post.uploads.each do |upload|
        delivered =
          DiscourseDisteleplus::ForumUploadLink.exists?(post_id: post.id, upload_id: upload.id)
        next if delivered
        Jobs.enqueue(:disteleplus_send_forum_upload, post_id: post.id, upload_id: upload.id)
      end
    end
  end
end
