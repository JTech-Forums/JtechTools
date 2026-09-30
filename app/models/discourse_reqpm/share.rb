# frozen_string_literal: true

module DiscourseReqpm
  # "owner lets recipient see this one contact method." The only thing that
  # makes a method readable by anyone other than its owner.
  class Share < ActiveRecord::Base
    self.table_name = "reqpm_shares"

    belongs_to :owner, class_name: "User"
    belongs_to :recipient, class_name: "User"
    belongs_to :contact_method, class_name: "DiscourseReqpm::ContactMethod"

    validates :contact_method_id, uniqueness: { scope: :recipient_id }
    validate :method_belongs_to_owner

    private

    def method_belongs_to_owner
      return if contact_method.nil? || contact_method.user_id == owner_id
      errors.add(:contact_method_id, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: reqpm_shares
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  contact_method_id :bigint           not null
#  owner_id          :bigint           not null
#  recipient_id      :bigint           not null
#
# Indexes
#
#  index_reqpm_shares_on_contact_method_id_and_recipient_id  (contact_method_id,recipient_id) UNIQUE
#  index_reqpm_shares_on_owner_id_and_recipient_id           (owner_id,recipient_id)
#  index_reqpm_shares_on_recipient_id_and_owner_id           (recipient_id,owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_method_id => reqpm_contact_methods.id) ON DELETE => cascade
#  fk_rails_...  (owner_id => users.id) ON DELETE => cascade
#  fk_rails_...  (recipient_id => users.id) ON DELETE => cascade
#
