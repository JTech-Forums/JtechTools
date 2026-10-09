# frozen_string_literal: true

module DiscourseModElections
  # Casting, changing and taking back a ballot during Vote Week.
  module Voting
    def self.cast!(user, election, ranking, ip_address: nil)
      voter = Voter.find_by(election_id: election.id, user_id: user.id)
      reason = Eligibility.vote_blocked_reason(user, election, voter)
      raise Error.new(reason) if reason

      ids = Array(ranking).map(&:to_i)
      raise Error.new(:empty_ballot) if ids.empty?
      raise Error.new(:invalid_ballot) if ids.uniq.size != ids.size

      running = election.candidates.running.pluck(:id, :user_id).to_h
      raise Error.new(:invalid_ballot) unless ids.all? { |id| running.key?(id) }
      raise Error.new(:self_vote) if ids.any? { |id| running[id] == user.id }

      ballot = Ballot.find_or_initialize_by(election_id: election.id, user_id: user.id)
      raise Error.new(:ballot_voided) if ballot.voided?
      ballot.update!(ranking: ids, weight: voter.weight, ip_address: ip_address)
      ballot
    end

    def self.clear!(user, election)
      raise Error.new(:not_voting) unless election.voting?
      ballot = Ballot.find_by(election_id: election.id, user_id: user.id)
      raise Error.new(:ballot_voided) if ballot&.voided?
      ballot&.destroy!
    end

    def self.void!(ballot, reason, actor)
      raise Error.new(:finished) unless ballot.election.unfinished?
      reason = reason.to_s.strip
      raise Error.new(:reason_required) if reason.blank?
      ballot.update!(voided_at: Time.zone.now, voided_by: actor, void_reason: reason.truncate(500))
      StaffActionLogger.new(actor).log_custom(
        "mod_election_void_ballot",
        target_user_id: ballot.user_id,
        election_id: ballot.election_id,
        reason: reason,
      )
    end

    def self.restore!(ballot, actor)
      raise Error.new(:finished) unless ballot.election.unfinished?
      ballot.update!(voided_at: nil, voided_by: nil, void_reason: nil)
      StaffActionLogger.new(actor).log_custom(
        "mod_election_restore_ballot",
        target_user_id: ballot.user_id,
        election_id: ballot.election_id,
      )
    end
  end
end
