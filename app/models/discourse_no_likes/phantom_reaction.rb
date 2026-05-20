# frozen_string_literal: true

module DiscourseNoLikes
  class PhantomReaction < ActiveRecord::Base
    self.table_name = "discourse_no_likes_phantoms"

    belongs_to :post
    belongs_to :user
  end
end

# == Schema Information
#
# Table name: discourse_no_likes_phantoms
#
#  id            :bigint           not null, primary key
#  reaction_type :string           default("like"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  category_id   :integer          not null
#  post_id       :integer          not null
#  user_id       :integer          not null
#
# Indexes
#
#  index_discourse_no_likes_phantoms_on_category_id          (category_id)
#  index_discourse_no_likes_phantoms_on_post_id_and_user_id  (post_id,user_id)
#  index_discourse_no_likes_phantoms_on_user_id              (user_id)
#
