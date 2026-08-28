# frozen_string_literal: true

module Jobs
  # Periodic safety net for DiscourseDisteleplus::ChannelNotifications: picks
  # up users who joined an allowed group through a path that fires no event
  # (bulk group edits, SSO syncs, imports) and re-pins anything that drifted.
  # The membership before_save prepend handles the interactive case
  # instantly; this is for everything else.
  class DisteleplusSyncChannelNotifications < ::Jobs::Scheduled
    every 30.minutes

    def execute(_args)
      return unless DiscourseDisteleplus::ChannelNotifications.active?
      DiscourseDisteleplus::ChannelNotifications.enforce_all!
      if DiscourseDisteleplus::VoiceNotes.enabled?
        DiscourseDisteleplus::VoiceNotes.ensure_extensions_authorized!
      end
    end
  end
end
