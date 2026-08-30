# frozen_string_literal: true

module DiscourseDisteleplus
  class MessageUpload < ActiveRecord::Base
    self.table_name = "disteleplus_message_uploads"

    belongs_to :message,
               class_name: "DiscourseDisteleplus::Message",
               inverse_of: :message_uploads
    belongs_to :upload

    validates :upload_id, uniqueness: { scope: :message_id }
  end
end
