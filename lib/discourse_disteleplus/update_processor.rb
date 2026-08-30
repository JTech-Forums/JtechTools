# frozen_string_literal: true

module DiscourseDisteleplus
  # Inbound pipeline: one parsed Telegram Update (string keys, straight from
  # the webhook job) in, at most one Discourse chat write out.
  #
  # Flow per message: gate (right group?) → dedupe/echo-check via the link
  # table → match the sender to a Discourse user → download media within the
  # size cap → format → create/revise the chat message → record the link.
  class UpdateProcessor
    def initialize(update)
      @update = update
    end

    def process
      if (msg = @update["message"])
        handle_message(msg)
      elsif (msg = @update["edited_message"])
        handle_edit(msg)
      elsif (poll = @update["poll"])
        handle_poll_state(poll)
      elsif (reaction = @update["message_reaction"])
        handle_reaction(reaction)
      elsif (callback = @update["callback_query"])
        # Report action buttons. All authorization (reports chat, explicit
        # telegram_id staff mapping, rate limits) happens inside Reports.
        Rails.logger.info(
          "#{LOG_TAG} callback #{callback["data"].inspect} from tg user #{callback.dig("from", "id")}",
        )
        Reports.handle_callback(callback)
      end
    end

    private

    def handle_message(msg)
      return if SetupCommandHandler.new(msg).process?

      unless bridge_message?(msg)
        # A misconfigured chat id fails silently otherwise — the #1 setup
        # trap. Loud enough to show in /logs, cheap enough to ignore if the
        # bot deliberately sits in other groups.
        Rails.logger.warn(
          "#{LOG_TAG} ignoring message from chat #{msg.dig("chat", "id")} — " \
            "disteleplus_telegram_chat_id is #{SiteSetting.disteleplus_telegram_chat_id.inspect}",
        )
        return
      end
      return if msg["from"].nil? || msg.dig("from", "is_bot")
      # The polls toggle gates the whole feature — including the initial poll
      # snapshot, not just the later vote-count refreshes.
      return if msg["poll"] && !SiteSetting.disteleplus_bridge_polls
      return if MessageLink.for_telegram(msg.dig("chat", "id"), msg["message_id"]).exists?

      sender = UserMatcher.match(msg["from"])
      poster = sender || DiscourseDisteleplus.bot_user
      if poster.nil?
        Rails.logger.warn("#{LOG_TAG} dropping message #{msg["message_id"]}: no bridge bot user")
        return
      end

      upload_ids, media_note = process_media(msg, poster)

      text =
        if msg["poll"]
          poll_body = Formatter.poll_markdown(msg["poll"])
          poll_body
        else
          Formatter.inbound_text(msg, matched: true)
        end
      text = [text, media_note].compact_blank.join("\n")
      return if text.blank? && upload_ids.blank?

      reply_link =
        if msg["reply_to_message"]
          MessageLink.for_telegram(
            msg.dig("chat", "id"),
            msg.dig("reply_to_message", "message_id"),
          ).first
        end

      message =
        MessageService.new(actor: poster, bypass_access: true).create!(
          raw: text,
          upload_ids: upload_ids,
          reply_to_id: reply_link&.disteleplus_message_id,
          source: :telegram,
          external_sender_name: sender ? nil : Formatter.sender_display_name(msg["from"]),
          bridge: false,
        )

      MessageLink.create!(
        telegram_chat_id: msg.dig("chat", "id"),
        telegram_message_id: msg["message_id"],
        disteleplus_message_id: message.id,
        direction: :tg_to_discourse,
        kind: msg["poll"] ? :poll : (upload_ids.present? ? :media : :text),
        telegram_poll_id: msg.dig("poll", "id"),
      )
    end

    def handle_edit(msg)
      return unless SiteSetting.disteleplus_bridge_edits
      return unless bridge_message?(msg)

      link =
        MessageLink.for_telegram(msg.dig("chat", "id"), msg["message_id"]).tg_to_discourse.first
      return if link.nil?

      message = link.message
      return if message.nil?
      editor = message.user || DiscourseDisteleplus.bot_user
      return if editor.nil?

      text = Formatter.inbound_text(msg, matched: true)
      return if text.blank?

      MessageService.new(actor: editor, bypass_access: true).update_from_telegram!(
        message,
        raw: text,
      )
    end

    def handle_poll_state(poll)
      return unless SiteSetting.disteleplus_bridge_polls

      link = MessageLink.where(telegram_poll_id: poll["id"].to_s).first
      return if link.nil?

      message = link.message
      return if message.nil?
      editor = message.user || DiscourseDisteleplus.bot_user
      return if editor.nil?

      MessageService.new(actor: editor, bypass_access: true).update_from_telegram!(
        message,
        raw: Formatter.poll_markdown(poll),
      )
    end

    def handle_reaction(reaction)
      return unless SiteSetting.disteleplus_bridge_reactions
      return unless bridge_message?(reaction)
      # Anonymous (channel-identity) reactions carry actor_chat, not user.
      return if reaction["user"].nil?

      link = MessageLink.for_telegram(reaction.dig("chat", "id"), reaction["message_id"]).first
      return if link.nil?

      actor = UserMatcher.match(reaction["user"]) || DiscourseDisteleplus.bot_user
      return if actor.nil?

      old_chars = reaction_chars(reaction["old_reaction"])
      new_chars = reaction_chars(reaction["new_reaction"])

      (new_chars - old_chars).each do |char|
        if link.message
          MessageService.new(actor: actor, bypass_access: true).react!(
            link.message,
            emoji: EmojiMap.tg_to_discourse(char),
            action: :add,
            bridge: false,
          )
        end
      end
      (old_chars - new_chars).each do |char|
        if link.message
          MessageService.new(actor: actor, bypass_access: true).react!(
            link.message,
            emoji: EmojiMap.tg_to_discourse(char),
            action: :remove,
            bridge: false,
          )
        end
      end
    end

    # ── helpers ──────────────────────────────────────────────────────────────

    def bridge_chat?(chat_id)
      configured = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      configured.present? && chat_id.to_s == configured
    end

    def bridge_message?(message)
      return false unless bridge_chat?(message.dig("chat", "id"))

      actual_topic_id = message["message_thread_id"].to_i
      # The archive exclusion wins even under a mistaken duplicate topic
      # configuration: avoiding a privacy leak is more important than keeping
      # the Chat bridge alive until the setting is corrected.
      upload_topic_id = SiteSetting.disteleplus_forum_upload_topic_id.to_i
      if SiteSetting.disteleplus_forum_uploads_enabled && upload_topic_id.positive?
        return false if actual_topic_id == upload_topic_id
      end

      # Same for the moderation reports topic: flag discussions between
      # staff must never mirror into the member-facing conversation.
      return false if Reports.reports_thread_in_bridge_chat?(actual_topic_id)

      chat_topic_id = SiteSetting.disteleplus_chat_topic_id.to_i
      return actual_topic_id == chat_topic_id if chat_topic_id.positive?

      true
    end

    # Returns [upload_ids, note]. Either can be nil; a note replaces media we
    # could not (or chose not to) bring across.
    def process_media(msg, poster)
      source = media_source(msg)
      return nil, nil if source.nil?

      type, file_id, filename, note = source
      return nil, note if file_id.nil?
      return nil, Formatter.media_placeholder(type) unless SiteSetting.disteleplus_bridge_uploads

      max_bytes = SiteSetting.disteleplus_max_upload_mb.megabytes
      tempfile = TelegramApi.new.download_file(file_id, max_bytes: max_bytes)
      if tempfile.nil?
        return nil, Formatter.media_placeholder(type, size_bytes: declared_size(msg, type))
      end

      begin
        upload = UploadCreator.new(tempfile, filename, type: "composer").create_for(poster.id)
        if upload&.persisted?
          [[upload.id], nil]
        else
          errors = upload&.errors&.full_messages&.join(", ")
          Rails.logger.warn("#{LOG_TAG} upload failed: #{errors.presence || "unknown"}")
          [nil, Formatter.media_placeholder(type)]
        end
      ensure
        tempfile.close!
      end
    end

    # → [type_label, file_id, filename, note] or nil when the message carries
    # no media. A nil file_id with a note means "don't download, say this".
    def media_source(msg)
      if (sizes = msg["photo"]).present?
        largest = Array(sizes).max_by { |s| s["file_size"].to_i }
        ["photo", largest["file_id"], "photo.jpg", nil]
      elsif (doc = msg["document"])
        ["document", doc["file_id"], doc["file_name"].presence || "document", nil]
      elsif (video = msg["video"])
        ["video", video["file_id"], video["file_name"].presence || "video.mp4", nil]
      elsif (note = msg["video_note"])
        ["video note", note["file_id"], "video_note.mp4", nil]
      elsif (voice = msg["voice"])
        # Named so the custom player and the outbound sendVoice path both
        # recognise it as a voice note (see VoiceNotes.voice_note?).
        ["voice message", voice["file_id"], VoiceNotes.inbound_filename(voice), nil]
      elsif (audio = msg["audio"])
        ["audio", audio["file_id"], audio["file_name"].presence || "audio.mp3", nil]
      elsif (animation = msg["animation"])
        ["animation", animation["file_id"], animation["file_name"].presence || "animation.mp4", nil]
      elsif (sticker = msg["sticker"])
        if sticker["is_animated"] || sticker["is_video"]
          ["sticker", nil, nil, "[sticker #{sticker["emoji"]}]".squish]
        else
          ["sticker", sticker["file_id"], "sticker.webp", nil]
        end
      end
    end

    def declared_size(msg, type)
      key = { "photo" => nil, "video note" => "video_note", "voice message" => "voice" }
      field = key.fetch(type, type)
      if type == "photo"
        Array(msg["photo"]).map { |s| s["file_size"].to_i }.max
      else
        msg.dig(field, "file_size")
      end
    end

    def reaction_chars(list)
      Array(list).filter_map { |r| r["emoji"] if r["type"] == "emoji" }.uniq
    end
  end
end
