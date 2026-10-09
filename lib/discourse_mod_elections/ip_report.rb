# frozen_string_literal: true

module DiscourseModElections
  # The alt-account check: ballots cast from the same address as another
  # ballot, or as a candidate. Admins see who voted from where, never what
  # anyone ranked.
  module IpReport
    def self.for(election)
      ballots = election.ballots.where.not(ip_address: nil).includes(:user).to_a
      candidates = election.candidates.running.includes(:user).map(&:user).compact
      candidate_ips =
        candidates.each_with_object(Hash.new { |h, k| h[k] = [] }) do |user, map|
          [user.ip_address, user.registration_ip_address].compact
            .map(&:to_s)
            .uniq
            .each { |ip| map[ip] << user }
        end

      ballots
        .group_by { |ballot| ballot.ip_address.to_s }
        .filter_map do |ip, group|
          sharing = candidate_ips[ip].reject { |user| group.any? { |b| b.user_id == user.id } }
          next if group.size < 2 && sharing.empty?
          { ip: ip, ballots: group.sort_by(&:id), candidates: sharing }
        end
        .sort_by { |row| -row[:ballots].size }
    end
  end
end
