# frozen_string_literal: true

module Jobs
  class DisteleplusMeasureForumUploads < ::Jobs::Base
    def execute(_args)
      return unless SiteSetting.disteleplus_enabled
      DiscourseDisteleplus::ForumUploadMetrics.log!
    end
  end
end
