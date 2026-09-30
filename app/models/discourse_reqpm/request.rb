# frozen_string_literal: true

module DiscourseReqpm
  # "requester would like target's contact details." Carries no free text —
  # only which kinds of contact the requester would prefer — so it cannot be
  # used as a back door for private messages.
  class Request < ActiveRecord::Base
    self.table_name = "reqpm_requests"

    belongs_to :requester, class_name: "User"
    belongs_to :target, class_name: "User"

    enum :status, { pending: 0, fulfilled: 1, declined: 2, cancelled: 3, expired: 4 }

    validate :wanted_kinds_known

    # Pending and still inside the expiry window.
    scope :open_requests,
          -> { pending.where("reqpm_requests.created_at > ?", Request.expiry_cutoff) }

    def self.expiry_cutoff
      SiteSetting.reqpm_request_expiry_days.days.ago
    end

    def open?
      pending? && created_at > Request.expiry_cutoff
    end

    private

    def wanted_kinds_known
      return if Array(wanted_kinds).all? { |k| Kinds.valid?(k) }
      errors.add(:wanted_kinds, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: reqpm_requests
#
#  id           :bigint           not null, primary key
#  responded_at :datetime
#  status       :integer          default("pending"), not null
#  wanted_kinds :string           default([]), not null, is an Array
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  requester_id :bigint           not null
#  target_id    :bigint           not null
#
# Indexes
#
#  index_reqpm_requests_on_pair_and_created_at  (requester_id,target_id,created_at)
#  index_reqpm_requests_on_target_id_and_status                       (target_id,status)
#  index_reqpm_requests_one_pending_per_pair                          (requester_id,target_id) UNIQUE WHERE (status = 0)
#
# Foreign Keys
#
#  fk_rails_...  (requester_id => users.id) ON DELETE => cascade
#  fk_rails_...  (target_id => users.id) ON DELETE => cascade
#
