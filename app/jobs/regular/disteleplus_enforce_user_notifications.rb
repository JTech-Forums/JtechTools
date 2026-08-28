# frozen_string_literal: true

module Jobs
  # One-user enrollment into the bridge channel at notification level
  # "always". Enqueued from user lifecycle events (created/approved/added to
  # a group) so a new admin-team member is notified from their first minute,
  # not from the next 30-minute sync.
  class DisteleplusEnforceUserNotifications < ::Jobs::Base
    def execute(args)
      return unless DiscourseDisteleplus::ChannelNotifications.active?
      user = User.find_by(id: args[:user_id])
      return if user.nil?
      DiscourseDisteleplus::ChannelNotifications.enforce_user!(user)
    end
  end
end
