# frozen_string_literal: true

module DiscourseDisteleplus
  # Telegram-side setup wizard. Telegram messages always identify their chat
  # and thread numerically, so an admin can bind the right destinations by
  # issuing a command in context instead of copying IDs into Discourse.
  class SetupCommandHandler
    COMMAND = %r{
      \A/disteleplus_
      (setup|help|status|bind_general|bind_uploads|create_uploads)
      (?:@\w+)?
      (?:\s+(.+))?
      \z
    }ix
    ADMIN_STATUSES = %w[creator administrator].freeze
    DEFAULT_UPLOAD_TOPIC_NAME = "Uploads"

    def initialize(message, api: TelegramApi.new)
      @message = message
      @api = api
    end

    # Returns true whenever the message is a Disteleplus command—even on
    # failure—so setup chatter can never cross into the Discourse Chat bridge.
    def process?
      match = @message["text"].to_s.strip.match(COMMAND)
      return false if match.nil?

      unless SiteSetting.disteleplus_setup_commands_enabled
        reply("Setup commands are disabled in Discourse admin settings.")
        return true
      end
      unless group_message?
        reply("Run this command inside the JTech Telegram group.")
        return true
      end
      unless telegram_admin?
        reply("Only a Telegram group administrator can configure Disteleplus.")
        return true
      end
      unless authorized_group?
        reply(
          "Disteleplus is already bound to another group. " \
            "Clear the Telegram chat ID in Discourse admin before moving it.",
        )
        return true
      end

      command = match[1].downcase
      topic_name = normalized_topic_name(match[2])
      send("handle_#{command}", topic_name)
      true
    rescue TelegramApi::RateLimited
      raise
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} setup command failed: #{e.message}")
      reply("Setup failed. Check Discourse <code>/logs</code> for details.")
      true
    end

    private

    def handle_help(_topic_name)
      reply(<<~HTML.strip)
        <b>Disteleplus setup</b>

        In General:
        <code>/disteleplus_bind_general</code>

        Inside an existing Uploads topic:
        <code>/disteleplus_bind_uploads</code>

        Or create and bind it automatically from General:
        <code>/disteleplus_create_uploads Uploads</code>

        Check the saved destinations:
        <code>/disteleplus_status</code>

        Binding does not start history automatically.
        Measure and start the backfill from Discourse admin settings.
      HTML
    end

    alias handle_setup handle_help

    def handle_status(_topic_name)
      configured_chat = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      upload_name =
        SiteSetting.disteleplus_forum_upload_topic_name.presence || DEFAULT_UPLOAD_TOPIC_NAME
      upload_id = SiteSetting.disteleplus_forum_upload_topic_id.to_i
      group_state = configured_chat == chat_id.to_s ? "this group" : "another/unbound group"
      upload_state =
        if upload_id.positive?
          "#{escape(upload_name)} (<code>#{upload_id}</code>)"
        else
          "not bound"
        end
      mirror_state = SiteSetting.disteleplus_forum_uploads_enabled ? "enabled" : "disabled"

      reply(<<~HTML.strip)
        <b>Disteleplus status</b>
        Group: #{escape(chat_title)} — #{group_state}
        Chat bridge: General
        Upload archive: #{upload_state}
        Live upload mirror: #{mirror_state}
      HTML
    end

    def handle_bind_general(_topic_name)
      if thread_id.positive?
        reply(
          "Send <code>/disteleplus_bind_general</code> in the group's General " \
            "conversation, not inside a topic.",
        )
        return
      end

      bind_group!
      SiteSetting.disteleplus_chat_topic_id = 0
      reply(<<~HTML.strip)
        ✅ <b>General bound</b>
        Group: #{escape(chat_title)}
        Discourse Chat will continue using General.

        Next, enter the Uploads topic and send:
        <code>/disteleplus_bind_uploads</code>
      HTML
    end

    def handle_bind_uploads(topic_name)
      unless thread_id.positive?
        reply(
          "Run <code>/disteleplus_bind_uploads</code> inside the Telegram topic " \
            "that should receive uploads.",
        )
        return
      end
      if thread_id == SiteSetting.disteleplus_chat_topic_id.to_i
        reply("The upload archive and Discourse Chat cannot use the same Telegram topic.")
        return
      end

      bind_group!
      SiteSetting.disteleplus_forum_upload_topic_id = thread_id
      SiteSetting.disteleplus_forum_upload_topic_name = topic_name
      reply(<<~HTML.strip)
        ✅ <b>Upload topic bound</b>
        Topic: #{escape(topic_name)}
        Group: #{escape(chat_title)}

        New and historical forum files will use this topic after the mirror
        is enabled in Discourse.
        Run <code>/disteleplus_status</code> to verify.
      HTML
    end

    def handle_create_uploads(topic_name)
      if thread_id.positive?
        reply(
          "Create the archive from General, or use " \
            "<code>/disteleplus_bind_uploads</code> in an existing topic.",
        )
        return
      end
      if SiteSetting.disteleplus_forum_upload_topic_id.to_i.positive?
        reply(
          "An upload topic is already bound. Run <code>/disteleplus_status</code>, " \
            "or bind a different existing topic with <code>/disteleplus_bind_uploads</code>.",
        )
        return
      end

      result = @api.call("createForumTopic", chat_id: chat_id, name: topic_name)
      unless result.ok
        reply(
          "Could not create the topic: #{escape(result.description)}. " \
            "Give the bot permission to manage topics, or bind an existing topic.",
        )
        return
      end

      created_thread_id = result.result&.dig("message_thread_id").to_i
      unless created_thread_id.positive?
        raise "createForumTopic returned no message_thread_id"
      end

      bind_group!
      SiteSetting.disteleplus_forum_upload_topic_id = created_thread_id
      SiteSetting.disteleplus_forum_upload_topic_name = topic_name
      reply(<<~HTML.strip)
        ✅ <b>Upload topic created and bound</b>
        Topic: #{escape(topic_name)}

        Enable the live mirror, measure the archive, and start history from
        Discourse admin settings.
      HTML
    end

    def telegram_admin?
      user_id = @message.dig("from", "id")
      return false if user_id.blank?

      result = @api.call("getChatMember", chat_id: chat_id, user_id: user_id)
      result.ok && ADMIN_STATUSES.include?(result.result&.dig("status"))
    end

    def authorized_group?
      configured = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      configured.blank? || configured == chat_id.to_s
    end

    def bind_group!
      previous_chat = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      if previous_chat.present? && previous_chat != chat_id.to_s
        SiteSetting.disteleplus_forum_upload_topic_id = 0
        SiteSetting.disteleplus_forum_upload_topic_name = DEFAULT_UPLOAD_TOPIC_NAME
      end
      SiteSetting.disteleplus_telegram_chat_id = chat_id.to_s
    end

    def reply(text)
      payload = { chat_id: chat_id, text: text, parse_mode: "HTML" }
      payload[:message_thread_id] = thread_id if thread_id.positive?
      payload[:reply_to_message_id] = @message["message_id"] if @message["message_id"]
      result = @api.call("sendMessage", payload)
      unless result.ok
        Rails.logger.warn(
          "#{DiscourseDisteleplus::LOG_TAG} setup reply failed: #{result.description}",
        )
      end
      result
    end

    def normalized_topic_name(argument)
      argument.to_s.squish.presence&.first(128) || DEFAULT_UPLOAD_TOPIC_NAME
    end

    def group_message?
      %w[group supergroup].include?(@message.dig("chat", "type"))
    end

    def chat_id
      @message.dig("chat", "id")
    end

    def chat_title
      @message.dig("chat", "title").presence || chat_id.to_s
    end

    def thread_id
      @message["message_thread_id"].to_i
    end

    def escape(value)
      Formatter.escape_html(value.to_s)
    end
  end
end
