# frozen_string_literal: true

module DiscourseDisteleplus
  class UserState < ActiveRecord::Base
    self.table_name = "disteleplus_user_states"

    belongs_to :user
    belongs_to :last_read_message,
               class_name: "DiscourseDisteleplus::Message",
               optional: true

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
