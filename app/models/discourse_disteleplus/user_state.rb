# frozen_string_literal: true

module DiscourseDisteleplus
  class UserState < ActiveRecord::Base
    self.table_name = "disteleplus_user_states"

    belongs_to :user
    belongs_to :last_read_message, class_name: "DiscourseDisteleplus::Message", optional: true

    enum :notification_level, { never: 0, always: 1 }, prefix: true

    validates :user_id, uniqueness: true

    def advance_to!(message_id)
      candidate = message_id.to_i
      return self if candidate <= last_read_message_id.to_i

      update!(last_read_message_id: candidate)
      self
    end
  end
end

# == Schema Information
#
# Table name: disteleplus_user_states
#
#  id                   :bigint           not null, primary key
#  notification_level   :integer          default("always"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  last_read_message_id :bigint
#  user_id              :bigint           not null
#
# Indexes
#
#  index_disteleplus_user_states_on_last_read_message_id  (last_read_message_id)
#  index_disteleplus_user_states_on_user_id               (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (last_read_message_id => disteleplus_messages.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
