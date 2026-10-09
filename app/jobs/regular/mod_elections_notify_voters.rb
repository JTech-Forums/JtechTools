# frozen_string_literal: true

module Jobs
  # "Vote Week is open" for everyone on the voter list, and the reminder a
  # day before it ends for those who haven't voted.
  class ModElectionsNotifyVoters < ::Jobs::Base
    def execute(args)
      return unless DiscourseModElections.enabled?
      election = DiscourseModElections::Election.find_by(id: args[:election_id])
      return if election.nil? || !election.voting?
      kind = args[:kind].to_s
      ids = DiscourseModElections::Notifier.voter_ids(election, kind)
      DiscourseModElections::Notifier.notify(ids, election, kind)
    end
  end
end
