# frozen_string_literal: true

module DiscourseModElections
  # Bell notifications. They link to /elections and say which step it is;
  # never anything about anyone's ballot.
  #
  # Uses the `custom` notification type like the plugin's other features;
  # the shared client renderer (lib/mod-note-notification.ts) picks these up
  # by the `mod_election` marker in data.
  module Notifier
    KINDS = %w[on_ballot voting_open reminder closed results disqualified seat_filled].freeze
    PAGE = "/elections"
    BATCH = 500

    def self.notify(user_ids, election, kind)
      raise ArgumentError, "unknown kind #{kind}" if KINDS.exclude?(kind)
      data = payload(election, kind).to_json
      User
        .where(id: user_ids)
        .find_in_batches(batch_size: BATCH) do |users|
          users.each do |user|
            Notification.create!(
              notification_type: Notification.types[:custom],
              user_id: user.id,
              high_priority: %w[voting_open reminder closed].include?(kind),
              data: data,
            )
          end
        end
    end

    # Everyone on the voter list, or for the reminder only those who haven't
    # voted. Can be thousands of people, so it runs in a job.
    def self.enqueue_voters(election, kind)
      Jobs.enqueue(:mod_elections_notify_voters, election_id: election.id, kind: kind)
    end

    def self.voter_ids(election, kind)
      ids = Voter.where(election_id: election.id)
      ids =
        ids.where.not(user_id: Ballot.where(election_id: election.id).select(:user_id)) if kind ==
        "reminder"
      ids.pluck(:user_id)
    end

    def self.payload(election, kind)
      {
        mod_election: true,
        mod_election_kind: kind,
        mod_election_id: election.id,
        message: "mod_elections.notifications.#{kind}",
        title: "mod_elections.title",
        url: kind == "closed" ? "/admin/plugins/jtech-tools/mod-elections" : PAGE,
        display_username: "",
        excerpt: I18n.t("mod_elections.notifications.#{kind}"),
      }
    end
  end
end
