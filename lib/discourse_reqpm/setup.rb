# frozen_string_literal: true

module DiscourseReqpm
  # The "add your contact details" prompt, shown to new and existing users
  # alike until they have at least one way to be reached.
  #
  #   off      — never prompt
  #   gentle   — a friendly window with "Remind me later" (snoozes for
  #              reqpm_setup_snooze_days) and "I'd rather not" (stops asking)
  #   required — the window comes back on every page until something is
  #              added, like a missing required profile field
  module Setup
    def self.mode
      SiteSetting.reqpm_setup_prompt.to_s
    end

    # nil, "gentle" or "required" — what the client should show right now.
    def self.prompt_for(user)
      return nil if mode == "off"
      return nil unless Policy.can_use?(user)
      return nil if ContactMethod.exists?(user_id: user.id)
      return "required" if mode == "required"

      return nil if declined?(user)
      return nil if snoozed?(user)
      "gentle"
    end

    def self.declined?(user)
      ActiveModel::Type::Boolean.new.cast(user.custom_fields[DiscourseReqpm::SETUP_DECLINED_FIELD])
    end

    def self.snoozed?(user)
      raw = user.custom_fields[DiscourseReqpm::SETUP_SNOOZED_UNTIL_FIELD]
      return false if raw.blank?
      Time.zone.parse(raw.to_s)&.future? || false
    rescue ArgumentError
      false
    end

    def self.snooze!(user)
      user.custom_fields[DiscourseReqpm::SETUP_SNOOZED_UNTIL_FIELD] = SiteSetting
        .reqpm_setup_snooze_days
        .days
        .from_now
        .iso8601
      user.save_custom_fields(true)
    end

    def self.decline!(user)
      user.custom_fields[DiscourseReqpm::SETUP_DECLINED_FIELD] = true
      user.save_custom_fields(true)
    end
  end
end
