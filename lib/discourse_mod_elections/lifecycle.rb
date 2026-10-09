# frozen_string_literal: true

module DiscourseModElections
  # Moves elections along the calendar. Jobs::ModElectionsTick runs this
  # every few minutes; every step is safe to repeat.
  module Lifecycle
    def self.tick(now = Time.zone.now)
      return unless DiscourseModElections.enabled?
      schedule!(now)
      Election.unfinished.order(:id).each { |election| advance!(election, now) }
    end

    # Creates the election the calendar says should be running, unless one
    # already exists for that date (a cancelled one counts, so cancelling
    # sticks) or another is still unfinished.
    def self.schedule!(now)
      dates = Schedule.slot_at(now)
      return if dates.nil?
      return if Election.exists?(nominations_open_at: dates[:nominations_open_at])
      return if Election.unfinished.exists?
      Election.create!(dates.merge(seats: SiteSetting.mod_elections_seats))
    end

    def self.advance!(election, now = Time.zone.now)
      changed = false
      election.with_lock do
        if election.scheduled? && now >= election.nominations_open_at
          open_nominations!(election, now)
          changed = true
        end
        if election.nominating? && now >= election.voting_open_at
          open_voting!(election)
          changed = true
        end
        if election.voting? && election.reminder_sent_at.nil? &&
             now >= election.voting_close_at - 1.day && now < election.voting_close_at
          remind!(election, now)
        end
        if election.voting? && now >= election.voting_close_at
          close!(election)
          changed = true
        end
      end
      State.changed! if changed
      election
    end

    def self.open_nominations!(election, now)
      election.update!(status: :nominating)
      Roll.snapshot!(election, now: now)
      Nominations.add_incumbents!(election)
      Announcer.nominations_open(election)
    end

    def self.open_voting!(election)
      election.update!(status: :voting)
      Announcer.voting_open(election)
      Notifier.enqueue_voters(election, "voting_open") if SiteSetting.mod_elections_notify_voters
    end

    def self.remind!(election, now)
      election.update!(reminder_sent_at: now)
      Notifier.enqueue_voters(election, "reminder") if SiteSetting.mod_elections_notify_voters
    end

    def self.close!(election)
      # Under 2**53 so it survives a round trip through JavaScript exactly:
      # the seed is published so anyone can check a drawn lot.
      election.update!(status: :closed, seed: SecureRandom.random_number(2**52))
      Notifier.notify(User.real.where(admin: true).pluck(:id), election, "closed")
    end

    # An admin ends the current phase early.
    def self.end_phase!(election, actor, now = Time.zone.now)
      election.with_lock do
        if election.scheduled?
          gap = election.nominations_open_at - now
          election.update!(
            nominations_open_at: now,
            voting_open_at: election.voting_open_at - gap,
            voting_close_at: election.voting_close_at - gap,
          )
        elsif election.nominating?
          raise Error.new(:too_early) if now <= election.nominations_open_at
          election.update!(
            voting_open_at: now,
            voting_close_at: [election.voting_close_at, now + 1.minute].max,
          )
        elsif election.voting?
          election.update!(voting_close_at: now)
        else
          raise Error.new(:finished)
        end
      end
      StaffActionLogger.new(actor).log_custom(
        "mod_election_end_phase",
        election_id: election.id,
        status: election.status,
      )
      advance!(election.reload, now)
    end

    # An election an admin starts by hand, for dates off the calendar.
    def self.create!(actor, seats:, nominations_open_at:, voting_open_at:, voting_close_at:)
      raise Error.new(:election_in_progress) if Election.unfinished.exists?
      unless nominations_open_at && voting_open_at && voting_close_at &&
               nominations_open_at < voting_open_at && voting_open_at < voting_close_at
        raise Error.new(:invalid_dates)
      end
      election =
        Election.new(
          seats: seats,
          nominations_open_at: nominations_open_at,
          voting_open_at: voting_open_at,
          voting_close_at: voting_close_at,
          created_by: actor,
        )
      raise Error.new(:invalid_dates) unless election.valid?
      election.save!
      StaffActionLogger.new(actor).log_custom("mod_election_create", election_id: election.id)
      advance!(election)
    end
  end
end
