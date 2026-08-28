# frozen_string_literal: true

module DiscourseDisteleplus
  # Everything the server needs to know about voice notes.
  #
  # A voice note is an ordinary chat Upload whose filename starts with
  # VOICE_PREFIX — the composer's recorder names its files that way, and
  # inbound Telegram voice messages are renamed to match — so detection is
  # cheap, needs no extra column, and survives the file being downloaded and
  # re-shared. Anything else with an audio extension is just audio.
  #
  # Telegram will only render a proper voice bubble (waveform, no title,
  # plays inline) for sendVoice with OGG/OPUS, MP3 or M4A. Browsers record
  # OGG/OPUS (Firefox), WebM/OPUS (Chromium) or MP4/AAC (Safari), so WebM
  # is transcoded with ffmpeg when the binary is present, otherwise the note
  # degrades to sendAudio and still arrives.
  module VoiceNotes
    VOICE_PREFIX = "voice-note"
    # Legacy inbound name used before this module existed.
    LEGACY_INBOUND_NAME = "voice.ogg"

    # Extensions the recorder can produce, plus the one Telegram delivers.
    RECORDER_EXTENSIONS = %w[ogg webm m4a opus].freeze
    # What sendVoice accepts as-is.
    TELEGRAM_VOICE_EXTENSIONS = %w[ogg mp3 m4a opus].freeze

    FFMPEG_TIMEOUT_SECONDS = 60

    def self.enabled?
      SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_voice_notes_enabled
    end

    def self.voice_note?(upload)
      return false if upload.nil?
      name = upload.try(:original_filename).to_s.downcase
      return true if name == LEGACY_INBOUND_NAME
      name.start_with?(VOICE_PREFIX)
    end

    # Filename for a voice message arriving from Telegram.
    def self.inbound_filename(voice)
      duration = voice.is_a?(Hash) ? voice["duration"].to_i : 0
      duration.positive? ? "#{VOICE_PREFIX}-#{duration}s.ogg" : "#{VOICE_PREFIX}.ogg"
    end

    # The recorder uploads through core's /uploads.json, which enforces
    # authorized_extensions for non-staff. Adds whatever is missing, once,
    # with a log line — otherwise the mic button works for admins and fails
    # for everyone else with an opaque "not authorized" error.
    def self.ensure_extensions_authorized!
      current = SiteSetting.authorized_extensions.to_s
      return false if current.include?("*")

      have = current.split("|").map { |ext| ext.strip.downcase }.compact_blank
      missing = RECORDER_EXTENSIONS - have
      return false if missing.empty?

      SiteSetting.authorized_extensions = (have + missing).join("|")
      Rails.logger.info(
        "#{DiscourseDisteleplus::LOG_TAG} added #{missing.join(", ")} to authorized_extensions " \
          "for voice notes",
      )
      true
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} could not extend authorized_extensions: #{e.message}",
      )
      false
    end

    def self.ffmpeg_path
      return @ffmpeg_path if defined?(@ffmpeg_path)
      @ffmpeg_path =
        ENV["FFMPEG_PATH"].presence ||
          ENV["PATH"]
            .to_s
            .split(File::PATH_SEPARATOR)
            .map { |dir| File.join(dir, "ffmpeg") }
            .find { |p| File.executable?(p) }
    end

    def self.ffmpeg_available?
      ffmpeg_path.present?
    end

    # Decides how an upload goes to Telegram.
    #   → [method, field, io, filename, mime] where io may be a transcoded
    #     Tempfile (caller closes it) or the original io untouched.
    def self.telegram_send_plan(upload, io)
      ext = upload.extension.to_s.downcase
      filename = upload.original_filename.to_s
      return nil, nil, io, filename, nil unless voice_note?(upload)

      if TELEGRAM_VOICE_EXTENSIONS.include?(ext)
        return %w[sendVoice voice] + [io, filename, mime_for(ext)]
      end

      transcoded = transcode_to_ogg_opus(io, ext)
      if transcoded
        io.close if io.respond_to?(:close) && !io.equal?(transcoded)
        return(
          %w[sendVoice voice] + [transcoded, "#{File.basename(filename, ".*")}.ogg", "audio/ogg"]
        )
      end

      # No ffmpeg — still a real audio message, just not a voice bubble.
      %w[sendAudio audio] + [io, filename, mime_for(ext)]
    end

    def self.mime_for(ext)
      {
        "ogg" => "audio/ogg",
        "opus" => "audio/ogg",
        "mp3" => "audio/mpeg",
        "m4a" => "audio/mp4",
        "webm" => "audio/webm",
      }.fetch(ext, "application/octet-stream")
    end

    # Streams io into ffmpeg, producing an OGG/OPUS Tempfile (or nil).
    # -vn drops any stray video track; libopus at 48k mono ~32kbps is what
    # Telegram's own clients send.
    def self.transcode_to_ogg_opus(io, source_ext)
      return nil unless ffmpeg_available?
      return nil if io.nil?

      source = Tempfile.new(["disteleplus-voice-src", ".#{source_ext}"], binmode: true)
      io.rewind if io.respond_to?(:rewind)
      IO.copy_stream(io, source)
      source.flush

      target = Tempfile.new(%w[disteleplus-voice .ogg], binmode: true)
      command = [
        ffmpeg_path,
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        source.path,
        "-vn",
        "-ac",
        "1",
        "-ar",
        "48000",
        "-c:a",
        "libopus",
        "-b:a",
        "32k",
        "-f",
        "ogg",
        target.path,
      ]

      Discourse::Utils.execute_command(*command, timeout: FFMPEG_TIMEOUT_SECONDS)
      target.rewind
      if target.size.to_i.zero?
        target.close!
        return nil
      end
      target
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} voice transcode failed: #{e.class}: #{e.message}",
      )
      target&.close!
      nil
    ensure
      source&.close!
    end

    def self.status_summary
      return "off" unless SiteSetting.disteleplus_voice_notes_enabled
      scope =
        SiteSetting.disteleplus_voice_notes_bridge_channel_only ? "bridge channel" : "all channels"
      bubbles =
        (
          if ffmpeg_available?
            "Telegram voice bubbles for every browser"
          else
            "no ffmpeg — WebM notes arrive as audio files"
          end
        )
      "on — #{scope}, up to #{SiteSetting.disteleplus_voice_note_max_seconds}s, #{bubbles}"
    end
  end
end
