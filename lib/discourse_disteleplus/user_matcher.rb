# frozen_string_literal: true

module DiscourseDisteleplus
  # Resolves a Telegram User object to a Discourse User.
  #
  # Precedence: the manual `disteleplus_user_mappings` setting
  # ("telegram_username:discourse_username" pairs) wins over the automatic
  # same-username match. Telegram accounts without a public @username can
  # only be reached via nothing — they bridge as the bot with a name prefix.
  module UserMatcher
    def self.match(from)
      tg_username = from&.dig("username").to_s.strip
      return nil if tg_username.blank?

      mapped = mappings[tg_username.downcase]
      return User.find_by_username(mapped) if mapped

      User.find_by_username(tg_username)
    end

    # { "tg_username" (downcased, no @) => "discourse_username" }
    def self.mappings
      SiteSetting
        .disteleplus_user_mappings
        .to_s
        .split("|")
        .filter_map do |pair|
          tg, dc = pair.split(":", 2)
          tg = tg.to_s.strip.delete_prefix("@").downcase
          dc = dc.to_s.strip
          [tg, dc] if tg.present? && dc.present?
        end
        .to_h
    end
  end
end
