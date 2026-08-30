# frozen_string_literal: true

module DiscourseDisteleplus
  class Reaction < ActiveRecord::Base
    self.table_name = "disteleplus_reactions"

    belongs_to :message, class_name: "DiscourseDisteleplus::Message", inverse_of: :reactions
    belongs_to :user

    validates :emoji,
              presence: true,
              length: {
                maximum: 100,
              },
              uniqueness: {
                scope: %i[message_id user_id],
              }
  end
end

# == Schema Information
#
# Table name: disteleplus_reactions
#
#  id         :bigint           not null, primary key
#  emoji      :string(100)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  message_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_disteleplus_reactions_unique        (message_id,user_id,emoji) UNIQUE
#  index_disteleplus_reactions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (message_id => disteleplus_messages.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
