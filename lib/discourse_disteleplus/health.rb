# frozen_string_literal: true

module DiscourseDisteleplus
  # Remembers the most recent Telegram delivery failure so the admin dashboard
  # problem check can surface it instead of it living only in /logs.
  module Health
    STORE = "disteleplus"
    KEY = "last_telegram_error"
    WINDOW = 24.hours

    def self.record_error(description, context: nil)
      PluginStore.set(
        STORE,
        KEY,
        { "description" => description.to_s.first(500), "context" => context.to_s, "at" => Time.zone.now.iso8601 },
      )
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} could not record health error: #{e.message}")
    end

    def self.clear!
      PluginStore.remove(STORE, KEY)
    end

    def self.last_error
      value = PluginStore.get(STORE, KEY)
      return nil if value.blank?
      at = Time.zone.parse(value["at"].to_s) rescue nil
      return nil if at.nil? || at < WINDOW.ago
      value
    end

    def self.error_key_for(description)
      text = description.to_s.downcase
      if text.include?("chat not found")
        "chat_not_found"
      elsif text.include?("forbidden") || text.include?("kicked")
        "forbidden"
      elsif text.include?("thread not found") || text.include?("topic")
        "topic_not_found"
      else
        "generic"
      end
    end
  end
end
