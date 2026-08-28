# frozen_string_literal: true

module DiscourseDisteleplus
  # Durable delivery receipt for one appearance of an upload in a forum post.
  # An Upload may be referenced by multiple posts, so the occurrence identity
  # is the (post_id, upload_id) pair rather than upload_id alone.
  class ForumUploadLink < ActiveRecord::Base
    self.table_name = "disteleplus_forum_upload_links"

    belongs_to :post
    belongs_to :upload

    validates :upload_sha1, format: { with: /\A[0-9a-f]{40}\z/i }, allow_nil: true

    scope :for_upload_hash, ->(sha1) { where(upload_sha1: sha1.to_s.strip.downcase) }
  end
end

# == Schema Information
#
# Table name: disteleplus_forum_upload_links
#
#  id                  :bigint           not null, primary key
#  file_copied         :boolean          default(TRUE), not null
#  upload_sha1         :string(40)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  post_id             :bigint           not null
#  telegram_chat_id    :bigint           not null
#  telegram_message_id :bigint           not null
#  telegram_topic_id   :bigint           not null
#  upload_id           :bigint           not null
#
# Indexes
#
#  idx_disteleplus_forum_upload_post_upload             (post_id,upload_id) UNIQUE
#  idx_disteleplus_forum_upload_telegram                (telegram_chat_id,telegram_message_id) UNIQUE
#  index_disteleplus_forum_upload_links_on_upload_id    (upload_id)
#  index_disteleplus_forum_upload_links_on_upload_sha1  (upload_sha1)
#
