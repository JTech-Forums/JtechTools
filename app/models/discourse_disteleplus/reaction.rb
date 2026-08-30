# frozen_string_literal: true

module DiscourseDisteleplus
  class Reaction < ActiveRecord::Base
    self.table_name = "disteleplus_reactions"

    belongs_to :message,
               class_name: "DiscourseDisteleplus::Message",
               inverse_of: :reactions
    belongs_to :user

    validates :emoji,
              presence: true,
              length: { maximum: 100 },
              uniqueness: { scope: %i[message_id user_id] }
  end
end
