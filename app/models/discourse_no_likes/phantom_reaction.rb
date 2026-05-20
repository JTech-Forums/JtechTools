# frozen_string_literal: true

module DiscourseNoLikes
  class PhantomReaction < ActiveRecord::Base
    self.table_name = "discourse_no_likes_phantoms"

    belongs_to :post
    belongs_to :user
  end
end
