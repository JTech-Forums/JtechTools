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
      end
    end

    private

    def handle_message(msg)
      return unless bridge_chat?(msg.dig("chat", "id"))
      return if msg["from"].nil? || msg.dig("from", "is_bot")
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
          if sender
            poll_body
          else
            Formatter.prefixed(Formatter.sender_display_name(msg["from"]), "\n#{poll_body}")
          end
        else
          Formatter.inbound_text(msg, matched: sender.present?)
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

      ChatAdapter.ensure_membership(channel_id: channel_id, user: poster)
      chat_message =
        create_with_bot_fallback(
          poster: poster,
          sender: sender,
          from: msg["from"],
          text: text,
          upload_ids: upload_ids,
          in_reply_to_id: reply_link&.chat_message_id,
        )
      return if chat_message.nil?

      MessageLink.create!(
        telegram_chat_id: msg.dig("chat", "id"),
        telegram_message_id: msg["message_id"],
        chat_message_id: chat_message.id,
        direction: :tg_to_discourse,
        kind: msg["poll"] ? :poll : (upload_ids.present? ? :media : :text),
        telegram_poll_id: msg.dig("poll", "id"),
      )
    end

    def handle_edit(msg)
      return unless SiteSetting.disteleplus_bridge_edits
      return unless bridge_chat?(msg.dig("chat", "id"))

      link =
        MessageLink.for_telegram(msg.dig("chat", "id"), msg["message_id"]).tg_to_discourse.first
      return if link.nil?

      editor = chat_message_author(link.chat_message_id) || DiscourseDisteleplus.bot_user
      return if editor.nil?

      matched = UserMatcher.match(msg["from"]).present?
      text = Formatter.inbound_text(msg, matched: matched)
      return if text.blank?

      ChatAdapter.update_message(message_id: link.chat_message_id, user: editor, text: text)
    end

    def handle_poll_state(poll)
      return unless SiteSetting.disteleplus_bridge_polls

      link = MessageLink.where(telegram_poll_id: poll["id"].to_s).first
      return if link.nil?

      editor = chat_message_author(link.chat_message_id) || DiscourseDisteleplus.bot_user
      return if editor.nil?

      ChatAdapter.update_message(
        message_id: link.chat_message_id,
        user: editor,
        text: Formatter.poll_markdown(poll),
      )
    end

    def handle_reaction(reaction)
      return unless SiteSetting.disteleplus_bridge_reactions
      return unless bridge_chat?(reaction.dig("chat", "id"))
      # Anonymous (channel-identity) reactions carry actor_chat, not user.
      return if reaction["user"].nil?

      link = MessageLink.for_telegram(reaction.dig("chat", "id"), reaction["message_id"]).first
      return if link.nil?

      actor = UserMatcher.match(reaction["user"]) || DiscourseDisteleplus.bot_user
      return if actor.nil?

      old_chars = reaction_chars(reaction["old_reaction"])
      new_chars = reaction_chars(reaction["new_reaction"])

      (new_chars - old_chars).each do |char|
        ChatAdapter.react(
          message_id: link.chat_message_id,
          user: actor,
          emoji: EmojiMap.tg_to_discourse(char),
          action: :add,
        )
      end
      (old_chars - new_chars).each do |char|
        ChatAdapter.react(
          message_id: link.chat_message_id,
          user: actor,
          emoji: EmojiMap.tg_to_discourse(char),
          action: :remove,
        )
      end
    end

    # ── helpers ──────────────────────────────────────────────────────────────

    def bridge_chat?(chat_id)
      configured = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      configured.present? && chat_id.to_s == configured
    end

    def channel_id
      SiteSetting.disteleplus_chat_channel_id
    end

    def chat_message_author(chat_message_id)
      ChatAdapter.find_message(chat_message_id)&.user
    end

    # Matched users can still be rejected by channel policy (e.g. trust level
    # below the channel restriction); retry once as the bridge bot with the
    # author prefix so the message isn't lost.
    def create_with_bot_fallback(poster:, sender:, from:, text:, upload_ids:, in_reply_to_id:)
      ChatAdapter.create_message(
        channel_id: channel_id,
        user: poster,
        text: text,
        upload_ids: upload_ids,
        in_reply_to_id: in_reply_to_id,
      )
    rescue ChatAdapter::BridgeError => e
      bot = DiscourseDisteleplus.bot_user
      if sender.nil? || bot.nil? || poster.id == bot.id
        Rails.logger.warn("#{LOG_TAG} chat create failed: #{e.message}")
        return nil
      end

      Rails.logger.warn(
        "#{LOG_TAG} chat create as #{poster.username} failed (#{e.message}); retrying as bot",
      )
      ChatAdapter.ensure_membership(channel_id: channel_id, user: bot)
      ChatAdapter.create_message(
        channel_id: channel_id,
        user: bot,
        text: Formatter.prefixed(Formatter.sender_display_name(from), text),
        upload_ids: upload_ids,
        in_reply_to_id: in_reply_to_id,
      )
    rescue StandardError => e
      Rails.logger.warn("#{LOG_TAG} chat create failed: #{e.class}: #{e.message}")
      nil
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
        ["voice message", voice["file_id"], "voice.ogg", nil]
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
