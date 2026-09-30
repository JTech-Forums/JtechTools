# frozen_string_literal: true

module Jobs
  # Closes REQ-PM requests nobody answered within reqpm_request_expiry_days
  # (every read already treats them as expired; this just settles the rows)
  # and drops closed requests after a while — they only exist to enforce
  # the re-request cooldown and to show "answered" in the requester's list.
  class ReqpmExpireRequests < ::Jobs::Scheduled
    every 1.day

    KEEP_CLOSED_FOR = 90.days

    def execute(_args)
      return unless DiscourseReqpm.enabled?

      DiscourseReqpm::Request
        .pending
        .where("created_at <= ?", DiscourseReqpm::Request.expiry_cutoff)
        .update_all(status: DiscourseReqpm::Request.statuses[:expired], updated_at: Time.zone.now)

      DiscourseReqpm::Request
        .where.not(status: :pending)
        .where("updated_at <= ?", KEEP_CLOSED_FOR.ago)
        .delete_all
    end
  end
end
