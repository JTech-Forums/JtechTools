# frozen_string_literal: true

module DiscourseModElections
  # Filling a seat someone left mid-term: count the same ballots again
  # without the people who left, and the first newly elected candidate
  # takes the seat. No new vote.
  module Countback
    # The election whose seats are being served now.
    def self.current_election
      Election.published.order(published_at: :desc).first
    end

    # The candidate who would take the seat, or nil when nobody is left.
    def self.replacement(election)
      excluded = election.candidates.where.not(seat_left_at: nil).pluck(:id)
      seated = election.candidates.seated.pluck(:id)
      loop do
        result = Tally.count(election, excluded: excluded)
        id = result.elected.find { |candidate_id| seated.exclude?(candidate_id) }
        return if id.nil?
        candidate = election.candidates.includes(:user).find(id)
        return candidate if eligible?(candidate.user)
        # Suspended, made an admin or already a moderator since: skip them
        # and count again.
        excluded << id
      end
    end

    def self.eligible?(user)
      Eligibility.member?(user) && !user.admin? && !user.moderator?
    end

    def self.fill!(election, actor)
      raise Error.new(:not_found) unless election == current_election
      seats_open = election.seats - election.candidates.seated.count
      raise Error.new(:no_open_seat) if seats_open <= 0
      candidate = replacement(election)
      raise Error.new(:no_replacement) if candidate.nil?

      user = candidate.user
      user.grant_moderation!
      StaffActionLogger.new(actor).log_grant_moderation(user)
      Seats.seat_trust_level!(user, actor)
      candidate.update!(elected: true)

      result = election.result || {}
      result["countbacks"] = Array(result["countbacks"]) +
        [{ "candidate" => candidate.id, "at" => Time.zone.now.iso8601 }]
      election.update!(result: result)

      Announcer.countback(election, candidate)
      Notifier.notify([user.id], election, "seat_filled")
      candidate
    end
  end
end
