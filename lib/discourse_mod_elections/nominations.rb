# frozen_string_literal: true

module DiscourseModElections
  # Getting on (and off) the ballot.
  module Nominations
    # Sitting moderators go on the ballot when nominations open. They can
    # drop out until nominations close.
    def self.add_incumbents!(election)
      ids = Seats.sitting.pluck(:id)
      return if ids.empty?
      now = Time.zone.now
      rows =
        ids.map do |user_id|
          {
            election_id: election.id,
            user_id: user_id,
            incumbent: true,
            status: Candidate.statuses[:running],
            created_at: now,
            updated_at: now,
          }
        end
      Candidate.insert_all(rows, unique_by: %i[election_id user_id])
      Notifier.notify(ids, election, "on_ballot")
    end

    def self.run!(user, election, statement)
      reason = Eligibility.run_blocked_reason(user, election)
      raise Error.new(reason) if reason
      candidate = election.candidates.find_or_initialize_by(user_id: user.id)
      candidate.status = :running
      candidate.statement = clean(statement)
      save!(candidate)
    end

    def self.update_statement!(user, election, statement)
      raise Error.new(:not_nominating) unless election.nominating?
      candidate = own_candidacy!(user, election)
      candidate.statement = clean(statement)
      save!(candidate)
    end

    def self.withdraw!(user, election)
      raise Error.new(:not_nominating) unless election.nominating?
      own_candidacy!(user, election).update!(status: :withdrawn)
    end

    def self.disqualify!(candidate, reason, actor)
      raise Error.new(:finished) unless candidate.election.unfinished?
      reason = reason.to_s.strip
      raise Error.new(:reason_required) if reason.blank?
      candidate.update!(
        status: :disqualified,
        disqualified_reason: reason.truncate(500),
        disqualified_by: actor,
      )
      StaffActionLogger.new(actor).log_custom(
        "mod_election_disqualify",
        target_user_id: candidate.user_id,
        election_id: candidate.election_id,
        reason: reason,
      )
      Notifier.notify([candidate.user_id], candidate.election, "disqualified")
    end

    def self.reinstate!(candidate, actor)
      raise Error.new(:finished) unless candidate.election.unfinished?
      raise Error.new(:not_found) unless candidate.disqualified?
      candidate.update!(status: :running, disqualified_reason: nil, disqualified_by: nil)
      StaffActionLogger.new(actor).log_custom(
        "mod_election_reinstate",
        target_user_id: candidate.user_id,
        election_id: candidate.election_id,
      )
    end

    def self.own_candidacy!(user, election)
      candidate = election.candidates.running.find_by(user_id: user.id)
      raise Error.new(:not_running) if candidate.nil?
      candidate
    end

    # Plain text: no HTML is ever rendered from it, but stray control
    # characters and runs of blank lines go.
    def self.clean(statement)
      statement.to_s.gsub(/\r\n?/, "\n").gsub(/[^\P{Cc}\n\t]/, "").gsub(/\n{3,}/, "\n\n").strip
    end

    def self.save!(candidate)
      max = SiteSetting.mod_elections_statement_max_length
      raise Error.new(:statement_too_long, max: max) if candidate.statement.length > max
      candidate.save!
      candidate
    end
  end
end
