# frozen_string_literal: true

module DiscourseDisteleplus
  # One row per user who has played a voice note — the "listened" receipt.
  class MessageListen < ActiveRecord::Base
    self.table_name = "disteleplus_message_listens"

    belongs_to :message, class_name: "DiscourseDisteleplus::Message"
    belongs_to :user

    validates :user_id, uniqueness: { scope: :message_id }
  end
end

# == Schema Information
#
# Table name: disteleplus_message_listens
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  message_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_on_message_id_user_id_1c25f6f52e  (message_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (message_id => disteleplus_messages.id)
#
