# frozen_string_literal: true

module DiscourseDisteleplus
  class MessageUpload < ActiveRecord::Base
    self.table_name = "disteleplus_message_uploads"

    belongs_to :message, class_name: "DiscourseDisteleplus::Message", inverse_of: :message_uploads
    belongs_to :upload

    validates :upload_id, uniqueness: { scope: :message_id }
  end
end

# == Schema Information
#
# Table name: disteleplus_message_uploads
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  message_id :bigint           not null
#  upload_id  :bigint           not null
#
# Indexes
#
#  idx_disteleplus_message_uploads_unique          (message_id,upload_id) UNIQUE
#  index_disteleplus_message_uploads_on_upload_id  (upload_id)
#
# Foreign Keys
#
#  fk_rails_...  (message_id => disteleplus_messages.id) ON DELETE => cascade
#  fk_rails_...  (upload_id => uploads.id) ON DELETE => cascade
#
