# frozen_string_literal: true

module DiscourseDisteleplus
  # Resolves a Telegram User object to a Discourse User.
  #
  # Precedence: a row in the `disteleplus_user_map` table setting matched by
  # numeric telegram_id wins, then a row matched by @username, then (when
  # disteleplus_auto_match_usernames allows it) the automatic same-username
  # match. A row pointing at a user who no longer exists falls back to the
  # next rule rather than silently matching nobody. Telegram accounts without
  # a public @username can only be reached via a telegram_id row — otherwise
  # they bridge as the bot with a name prefix.
  #
  # Security: Telegram usernames are NOT stable identity — an abandoned
  # @name can be re-claimed by a stranger, and anyone can rename themselves
  # to an unmapped name. So (1) staff accounts are never auto-matched by bare
  # username, and (2) privileged operations (moderation buttons, report-topic
  # binding) only accept `privileged_match`, which requires an explicit map
  # row carrying the permanent numeric telegram_id.
  module UserMatcher
    def self.match(from)
      if (by_id = mapped_user(id_mappings[from&.dig("id").to_s]))
        return by_id
      end

      tg_username = from&.dig("username").to_s.strip
      return nil if tg_username.blank?

      if (mapped = mappings[tg_username.downcase])
        user = mapped_user(mapped)
        return user if user
        Rails.logger.warn(
          "#{DiscourseDisteleplus::LOG_TAG} disteleplus_user_map: " \
            "@#{tg_username} -> #{mapped}, no such Discourse user",
        )
      end

      return nil unless SiteSetting.disteleplus_auto_match_usernames
      user = User.find_by_username(tg_username)
      # Never auto-impersonate staff: posting as a moderator/admin requires
      # an explicit mapping row created by an admin.
      user && !user.staff? ? user : nil
    end

    # Strict resolver for actions with teeth (report buttons, binding the
    # reports destination): only an explicit map row whose telegram_id equals
    # the sender's numeric id counts. Username rows and auto-matching are
    # deliberately not honored here.
    def self.privileged_match(from)
      tg_id = from&.dig("id").to_s
      return nil if tg_id.blank?
      mapped_user(id_mappings[tg_id])
    end

    def self.mapped_user(username)
      return nil if username.blank?
      User.find_by_username(username)
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

    # { "numeric telegram id" => "discourse_username" }
    def self.id_mappings
      rows(SiteSetting.disteleplus_user_map)
        .filter_map do |row|
          tg_id = row["telegram_id"].to_s.strip
          dc = row["discourse_username"].to_s.strip.delete_prefix("@")
          [tg_id, dc] if tg_id.match?(/\A\d{1,20}\z/) && dc.present?
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
