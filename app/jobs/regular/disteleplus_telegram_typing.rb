# frozen_string_literal: true

module Jobs
  # Mirrors a Discourse member typing into Telegram's "typing…" status. The
  # controller throttles enqueues; Telegram shows the status for ~5 seconds.
  class DisteleplusTelegramTyping < ::Jobs::Base
    def execute(_args)
      return unless SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_typing_to_telegram
      chat_id = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      return if chat_id.blank?

      payload = { chat_id: chat_id, action: "typing" }
      thread_id = DiscourseDisteleplus.telegram_thread_id(SiteSetting.disteleplus_chat_topic_id)
      payload[:message_thread_id] = thread_id if thread_id
      DiscourseDisteleplus::TelegramApi.new.call("sendChatAction", payload)
    rescue DiscourseDisteleplus::TelegramApi::RateLimited
      nil
    end
  end
end
