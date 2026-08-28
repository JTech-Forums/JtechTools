# frozen_string_literal: true

module Jobs
  # Pushes one Discourse chat action (create/edit/delete/react) to the
  # Telegram group. Enqueued by DiscourseDisteleplus.handle_chat_event /
  # handle_reaction_event, which have already done the channel/echo gating.
  #
  # Telegram cannot batch mixed media, so a chat message with N uploads fans
  # out to N Telegram messages (the first carries the author-prefixed text as
  # its caption); each gets its own MessageLink row and the first one — the
  # lowest telegram_message_id — is the edit target.
  class DisteleplusSendToTelegram < ::Jobs::Base
    # Bot API cap on files the bot itself sends.
    MAX_SEND_BYTES = 50 * 1024 * 1024

    IMAGE_EXT = %w[png jpg jpeg gif webp].freeze
    VIDEO_EXT = %w[mp4 mov webm].freeze
    AUDIO_EXT = %w[mp3 m4a ogg wav flac].freeze

    def execute(args)
      return unless SiteSetting.disteleplus_enabled

      @api = DiscourseDisteleplus::TelegramApi.new
      # Strip: a pasted trailing space in the setting makes Telegram answer
      # "chat not found" for an otherwise-correct id.
      @chat_id = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      return if @chat_id.blank?

      case args[:action]
      when "create"
        handle_create(args[:chat_message_id])
      when "edit"
        handle_edit(args[:chat_message_id])
      when "delete"
        handle_delete(args[:chat_message_id])
      when "react"
        handle_react(args[:chat_message_id])
      end
    rescue DiscourseDisteleplus::TelegramApi::RateLimited => e
      Jobs.enqueue_in(
        e.retry_after.seconds,
        :disteleplus_send_to_telegram,
        args.slice(:action, :chat_message_id),
      )
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} outbound #{args[:action]} failed: #{e.class}: #{e.message}",
      )
    end

    private

    def handle_create(chat_message_id)
      message = DiscourseDisteleplus::ChatAdapter.find_message(chat_message_id)
      return if message.nil?
      return if DiscourseDisteleplus::MessageLink.for_chat_message(message.id).exists?

      html = DiscourseDisteleplus::Formatter.outbound_html(author_name(message), message.message)
      reply_to = reply_target(message)
      uploads = DiscourseDisteleplus::ChatAdapter.message_uploads(message)
      # The uploads toggle gates both directions — inbound is checked in
      # UpdateProcessor#process_media.
      uploads = [] unless SiteSetting.disteleplus_bridge_uploads

      sent = [] # [[telegram_message, kind], ...]
      if uploads.blank?
        sent << [send_text(html, reply_to), :text]
      else
        uploads.each_with_index do |upload, index|
          caption = index.zero? ? html : nil
          sent << send_upload(upload, caption, index.zero? ? reply_to : nil)
        end
      end

      sent.each do |tg_message, kind|
        next if tg_message.nil?
        DiscourseDisteleplus::MessageLink.create!(
          telegram_chat_id: @chat_id,
          telegram_message_id: tg_message["message_id"],
          chat_message_id: message.id,
          direction: :discourse_to_tg,
          kind: kind,
        )
      end
    end

    def handle_edit(chat_message_id)
      link =
        DiscourseDisteleplus::MessageLink.for_chat_message(chat_message_id).discourse_to_tg.first
      return if link.nil?

      message = DiscourseDisteleplus::ChatAdapter.find_message(chat_message_id)
      return if message.nil?

      html = DiscourseDisteleplus::Formatter.outbound_html(author_name(message), message.message)
      payload = { chat_id: @chat_id, message_id: link.telegram_message_id, parse_mode: "HTML" }
      if link.kind_text?
        @api.call("editMessageText", payload.merge(text: html))
      else
        @api.call("editMessageCaption", payload.merge(caption: html))
      end
    end

    def handle_delete(chat_message_id)
      DiscourseDisteleplus::MessageLink
        .for_chat_message(chat_message_id)
        .discourse_to_tg
        .find_each do |link|
          result =
            @api.call("deleteMessage", chat_id: @chat_id, message_id: link.telegram_message_id)
          unless result.ok
            # Older than 48h or missing delete rights — log, still unlink.
            Rails.logger.warn(
              "#{DiscourseDisteleplus::LOG_TAG} delete failed: #{result.description}",
            )
          end
          link.destroy!
        end
    end

    # Mirrors the message's most recent Discourse reaction as the bot's ONE
    # allowed Telegram reaction; an empty reaction list clears it.
    def handle_react(chat_message_id)
      link = DiscourseDisteleplus::MessageLink.for_chat_message(chat_message_id).first
      return if link.nil?

      emojis = DiscourseDisteleplus::ChatAdapter.current_reaction_emojis(chat_message_id)
      reaction =
        if emojis.any?
          [{ type: "emoji", emoji: DiscourseDisteleplus::EmojiMap.discourse_to_tg(emojis.last) }]
        else
          []
        end

      @api.call(
        "setMessageReaction",
        chat_id: @chat_id,
        message_id: link.telegram_message_id,
        reaction: reaction,
      )
    end

    # ── send helpers ─────────────────────────────────────────────────────────

    def send_text(html, reply_to)
      payload = { chat_id: @chat_id, text: html, parse_mode: "HTML" }
      payload[:reply_to_message_id] = reply_to if reply_to
      result = @api.call("sendMessage", payload)
      result.ok ? result.result : log_send_failure(result)
    end

    # → [telegram_message, kind] (either may be nil on failure).
    def send_upload(upload, caption, reply_to)
      max_bytes = [SiteSetting.disteleplus_max_upload_mb.megabytes, MAX_SEND_BYTES].min
      if upload.filesize.to_i > max_bytes
        # Too big to push — send the forum URL instead (login-gated when
        # secure uploads are on; documented in the README).
        url = UrlHelper.absolute(upload.url)
        text = [caption, "📎 #{upload.original_filename}: #{url}"].compact.join("\n")
        return send_text(text, reply_to), :text
      end

      io = upload_io(upload)
      if io.nil?
        return [
          send_text([caption, "📎 #{upload.original_filename}"].compact.join("\n"), reply_to),
          :text
        ]
      end

      method, field = send_method_for(upload)
      fields = { chat_id: @chat_id }
      fields[:caption] = caption if caption.present?
      fields[:parse_mode] = "HTML" if caption.present?
      fields[:reply_to_message_id] = reply_to if reply_to

      begin
        result =
          @api.call_multipart(
            method,
            fields,
            file_field: field,
            io: io,
            filename: upload.original_filename,
          )
        result.ok ? [result.result, :media] : [log_send_failure(result), nil]
      ensure
        io.close
      end
    end

    def send_method_for(upload)
      ext = upload.extension.to_s.downcase
      if IMAGE_EXT.include?(ext) && ext != "gif"
        %w[sendPhoto photo]
      elsif ext == "gif"
        %w[sendAnimation animation]
      elsif VIDEO_EXT.include?(ext)
        %w[sendVideo video]
      elsif AUDIO_EXT.include?(ext)
        %w[sendAudio audio]
      else
        %w[sendDocument document]
      end
    end

    def upload_io(upload)
      if Discourse.store.external?
        Discourse.store.download(upload)
      else
        path = Discourse.store.path_for(upload)
        path && File.exist?(path) ? File.open(path, "rb") : nil
      end
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} upload read failed: #{e.message}")
      nil
    end

    def reply_target(message)
      in_reply_to_id = message.try(:in_reply_to_id)
      return nil if in_reply_to_id.blank?
      DiscourseDisteleplus::MessageLink.for_chat_message(in_reply_to_id).first&.telegram_message_id
    end

    def author_name(message)
      message.user&.username || "unknown"
    end

    def log_send_failure(result)
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} send failed: #{result.description}")
      nil
    end
  end
end
