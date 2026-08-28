# frozen_string_literal: true

module DiscourseDisteleplus
  # Resolves a Telegram User object to a Discourse User.
  #
  # Precedence: a row in the `disteleplus_user_map` table setting wins over
  # the automatic same-username match. A row pointing at a user who no longer
  # exists falls back to the automatic match rather than silently matching
  # nobody. Telegram accounts without a public @username can only be reached
  # via nothing — they bridge as the bot with a name prefix.
  module UserMatcher
    def self.match(from)
      tg_username = from&.dig("username").to_s.strip
      return nil if tg_username.blank?

      if (mapped = mappings[tg_username.downcase])
        user = User.find_by_username(mapped)
        return user if user
        Rails.logger.warn(
          "#{DiscourseDisteleplus::LOG_TAG} disteleplus_user_map: " \
            "@#{tg_username} -> #{mapped}, no such Discourse user",
        )
      end

      User.find_by_username(tg_username)
    end

    # { "tg_username" (downcased, no @) => "discourse_username" }
    def self.mappings
      rows(SiteSetting.disteleplus_user_map)
        .filter_map do |row|
          tg = row["telegram_username"].to_s.strip.delete_prefix("@").downcase
          dc = row["discourse_username"].to_s.strip.delete_prefix("@")
          [tg, dc] if tg.present? && dc.present?
        end
        .to_h
    end

    # `type: objects` settings read back as the raw JSON STRING they are
    # stored as (TypeSupervisor#to_rb_value has no objects branch), so parse
    # here and tolerate anything malformed.
    def self.rows(value)
      return value if value.is_a?(Array)
      parsed = JSON.parse(value.to_s)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} disteleplus_user_map is not valid JSON")
      []
    end
  end
end
