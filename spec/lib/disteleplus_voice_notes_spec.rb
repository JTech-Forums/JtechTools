# frozen_string_literal: true

require "rails_helper"

# Pure decisions about voice notes: what counts as one, how an inbound Telegram
# voice message is named, how an upload is routed to Telegram, and the
# authorized_extensions repair. ffmpeg is stubbed both ways so the routing is
# asserted regardless of what the CI image ships.
RSpec.describe DiscourseDisteleplus::VoiceNotes do
  let(:voice_notes) { described_class }

  let(:upload_struct) { Struct.new(:original_filename, :extension) }

  def upload(name)
    upload_struct.new(name, File.extname(name).delete("."))
  end

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_voice_notes_enabled = true
    if described_class.instance_variable_defined?(:@ffmpeg_path)
      described_class.remove_instance_variable(:@ffmpeg_path)
    end
  end

  describe ".voice_note?" do
    it "recognises recorder output and Telegram voice messages by filename" do
      expect(voice_notes.voice_note?(upload("voice-note-20260828-152213.webm"))).to eq(true)
      expect(voice_notes.voice_note?(upload("voice-note-12s.ogg"))).to eq(true)
      expect(voice_notes.voice_note?(upload("Voice-Note.m4a"))).to eq(true)
      expect(voice_notes.voice_note?(upload("voice.ogg"))).to eq(true)
    end

    it "does not treat ordinary audio as a voice note" do
      expect(voice_notes.voice_note?(upload("song.ogg"))).to eq(false)
      expect(voice_notes.voice_note?(upload("podcast.mp3"))).to eq(false)
      expect(voice_notes.voice_note?(nil)).to eq(false)
    end
  end

  describe ".inbound_filename" do
    it "embeds the Telegram-declared duration" do
      expect(voice_notes.inbound_filename({ "duration" => 25 })).to eq("voice-note-25s.ogg")
    end

    it "falls back to a bare name when Telegram omits the duration" do
      expect(voice_notes.inbound_filename({})).to eq("voice-note.ogg")
      expect(voice_notes.inbound_filename(nil)).to eq("voice-note.ogg")
    end
  end

  describe ".telegram_send_plan" do
    let(:io) { StringIO.new("audio-bytes") }

    it "leaves non-voice uploads to the caller's extension routing" do
      method, field, out_io, filename, mime = voice_notes.telegram_send_plan(upload("song.mp3"), io)
      expect(method).to be_nil
      expect(field).to be_nil
      expect(out_io).to equal(io)
      expect(filename).to eq("song.mp3")
      expect(mime).to be_nil
    end

    it "sends OGG voice notes straight through sendVoice" do
      method, field, out_io, filename, mime =
        voice_notes.telegram_send_plan(upload("voice-note-3s.ogg"), io)
      expect([method, field]).to eq(%w[sendVoice voice])
      expect(out_io).to equal(io)
      expect(filename).to eq("voice-note-3s.ogg")
      expect(mime).to eq("audio/ogg")
    end

    it "sends M4A voice notes through sendVoice as well" do
      method, field, _io, _name, mime = voice_notes.telegram_send_plan(upload("voice-note.m4a"), io)
      expect([method, field]).to eq(%w[sendVoice voice])
      expect(mime).to eq("audio/mp4")
    end

    context "with a WebM recording" do
      it "transcodes to OGG/OPUS and sends as a voice bubble when ffmpeg is present" do
        transcoded = Tempfile.new(%w[t .ogg])
        transcoded.write("ogg-bytes")
        transcoded.rewind
        allow(voice_notes).to receive(:transcode_to_ogg_opus).with(io, "webm").and_return(
          transcoded,
        )

        method, field, out_io, filename, mime =
          voice_notes.telegram_send_plan(upload("voice-note-20260828.webm"), io)
        expect([method, field]).to eq(%w[sendVoice voice])
        expect(out_io).to equal(transcoded)
        expect(filename).to eq("voice-note-20260828.ogg")
        expect(mime).to eq("audio/ogg")
        expect(io).to be_closed
      ensure
        transcoded&.close!
      end

      it "degrades to sendAudio when transcoding is unavailable" do
        allow(voice_notes).to receive(:transcode_to_ogg_opus).and_return(nil)

        method, field, out_io, filename, mime =
          voice_notes.telegram_send_plan(upload("voice-note-20260828.webm"), io)
        expect([method, field]).to eq(%w[sendAudio audio])
        expect(out_io).to equal(io)
        expect(filename).to eq("voice-note-20260828.webm")
        expect(mime).to eq("audio/webm")
      end
    end
  end

  describe ".transcode_to_ogg_opus" do
    it "returns nil without ffmpeg instead of raising" do
      allow(voice_notes).to receive(:ffmpeg_path).and_return(nil)
      expect(voice_notes.transcode_to_ogg_opus(StringIO.new("x"), "webm")).to be_nil
    end
  end

  describe ".ensure_extensions_authorized!" do
    it "adds the recorder extensions that are missing, once" do
      SiteSetting.authorized_extensions = "jpg|png|ogg"
      expect(voice_notes.ensure_extensions_authorized!).to eq(true)
      exts = SiteSetting.authorized_extensions.split("|")
      expect(exts).to include("jpg", "png", "ogg", "webm", "m4a", "opus")
      expect(exts.size).to eq(6)

      expect(voice_notes.ensure_extensions_authorized!).to eq(false)
    end

    it "leaves a wildcard alone" do
      SiteSetting.authorized_extensions = "*"
      expect(voice_notes.ensure_extensions_authorized!).to eq(false)
      expect(SiteSetting.authorized_extensions).to eq("*")
    end
  end

  describe ".status_summary" do
    it "reports scope, cap and bubble capability" do
      allow(voice_notes).to receive(:ffmpeg_available?).and_return(true)
      SiteSetting.disteleplus_voice_note_max_seconds = 120
      expect(voice_notes.status_summary).to include("native conversation", "120s", "voice bubbles")

      allow(voice_notes).to receive(:ffmpeg_available?).and_return(false)
      expect(voice_notes.status_summary).to include("no ffmpeg")

      SiteSetting.disteleplus_voice_notes_enabled = false
      expect(voice_notes.status_summary).to eq("off")
    end
  end
end
