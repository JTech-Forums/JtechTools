import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

// Voice-note recorder modal for the chat composer.
//
// Flow: open → (ask for the mic) → recording, with a live level meter and a
// countdown against disteleplus_voice_note_max_seconds → stop → preview
// (the browser's own decode of the fresh blob, through the same custom
// player styling) → send. Sending uploads the blob through core's
// /uploads.json as a `chat-composer` upload and then posts a message to the
// channel with only that upload — no text — so the note lands as its own
// bubble, exactly like a phone messenger.
//
// Codec choice, in order: OGG/OPUS (Firefox; what Telegram natively speaks),
// WebM/OPUS (Chromium; transcoded server-side for Telegram when ffmpeg is
// available), MP4/AAC (Safari). The file is always named
// `voice-note-<stamp>.<ext>` — that prefix is how the server and the player
// recognise a voice note (see lib/discourse_disteleplus/voice_notes.rb).
const CANDIDATE_TYPES = [
  { mime: "audio/ogg;codecs=opus", ext: "ogg" },
  { mime: "audio/webm;codecs=opus", ext: "webm" },
  { mime: "audio/webm", ext: "webm" },
  { mime: "audio/mp4", ext: "m4a" },
];

const METER_BARS = 24;

function pickType() {
  if (!window.MediaRecorder?.isTypeSupported) {
    return null;
  }
  return CANDIDATE_TYPES.find((c) => MediaRecorder.isTypeSupported(c.mime));
}

function stamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return (
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-` +
    `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  );
}

function formatTime(seconds) {
  const whole = Math.max(0, Math.round(seconds));
  const m = Math.floor(whole / 60);
  const s = whole % 60;
  return `${m}:${s < 10 ? "0" : ""}${s}`;
}

export default class DisteleplusVoiceRecorder extends Component {
  @service siteSettings;

  // idle | requesting | recording | preview | uploading | sent | error
  @tracked state = "idle";
  @tracked elapsed = 0;
  @tracked errorKey = null;
  @tracked previewUrl = null;
  @tracked levels = new Array(METER_BARS).fill(0.05);

  stream = null;
  recorder = null;
  chunks = [];
  blob = null;
  type = null;
  timer = null;
  startedAt = 0;
  analyser = null;
  audioCtx = null;
  meterFrame = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.teardown();
  }

  get maxSeconds() {
    return this.siteSettings.disteleplus_voice_note_max_seconds || 300;
  }

  get remaining() {
    return Math.max(0, this.maxSeconds - this.elapsed);
  }

  get supported() {
    return (
      !!navigator.mediaDevices?.getUserMedia &&
      !!window.MediaRecorder &&
      !!pickType()
    );
  }

  get isIdle() {
    return this.state === "idle";
  }

  get isRequesting() {
    return this.state === "requesting";
  }

  get isRecording() {
    return this.state === "recording";
  }

  get isPreview() {
    return this.state === "preview";
  }

  get isUploading() {
    return this.state === "uploading";
  }

  get isError() {
    return this.state === "error";
  }

  get elapsedLabel() {
    return formatTime(this.elapsed);
  }

  get maxLabel() {
    return formatTime(this.maxSeconds);
  }

  get nearLimit() {
    return this.isRecording && this.remaining <= 10;
  }

  get title() {
    return i18n("disteleplus.voice.title");
  }

  get errorMessage() {
    return this.errorKey ? i18n(this.errorKey) : "";
  }

  get meterStyle() {
    return this.levels.map((v) => `${Math.round(v * 100)}%`);
  }

  teardown() {
    clearInterval(this.timer);
    this.timer = null;
    if (this.meterFrame) {
      cancelAnimationFrame(this.meterFrame);
      this.meterFrame = null;
    }
    if (this.recorder && this.recorder.state !== "inactive") {
      try {
        this.recorder.stop();
      } catch {
        // Already stopping.
      }
    }
    this.recorder = null;
    this.stream?.getTracks().forEach((t) => t.stop());
    this.stream = null;
    this.audioCtx?.close?.();
    this.audioCtx = null;
    this.analyser = null;
    if (this.previewUrl) {
      URL.revokeObjectURL(this.previewUrl);
      this.previewUrl = null;
    }
  }

  fail(key) {
    this.teardown();
    this.errorKey = key;
    this.state = "error";
  }

  @action
  async start() {
    if (!this.supported) {
      this.fail("disteleplus.voice.errors.unsupported");
      return;
    }
    this.state = "requesting";
    this.errorKey = null;
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      });
    } catch (e) {
      const denied =
        e?.name === "NotAllowedError" || e?.name === "SecurityError";
      this.fail(
        denied
          ? "disteleplus.voice.errors.denied"
          : "disteleplus.voice.errors.no_microphone"
      );
      return;
    }

    this.type = pickType();
    this.chunks = [];
    try {
      this.recorder = new MediaRecorder(this.stream, {
        mimeType: this.type.mime,
        audioBitsPerSecond: 48000,
      });
    } catch {
      this.fail("disteleplus.voice.errors.unsupported");
      return;
    }

    this.recorder.addEventListener("dataavailable", (event) => {
      if (event.data?.size) {
        this.chunks.push(event.data);
      }
    });
    this.recorder.addEventListener("stop", () => this.finishRecording());
    this.recorder.addEventListener("error", () =>
      this.fail("disteleplus.voice.errors.recording_failed")
    );

    this.startMeter();
    this.recorder.start(250);
    this.startedAt = Date.now();
    this.elapsed = 0;
    this.state = "recording";
    this.timer = setInterval(() => {
      this.elapsed = (Date.now() - this.startedAt) / 1000;
      if (this.elapsed >= this.maxSeconds) {
        this.stop();
      }
    }, 200);
  }

  startMeter() {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) {
      return;
    }
    try {
      this.audioCtx = new AudioCtx();
      const source = this.audioCtx.createMediaStreamSource(this.stream);
      this.analyser = this.audioCtx.createAnalyser();
      this.analyser.fftSize = 256;
      source.connect(this.analyser);
      const data = new Uint8Array(this.analyser.frequencyBinCount);
      const tick = () => {
        if (!this.analyser) {
          return;
        }
        this.analyser.getByteTimeDomainData(data);
        let sum = 0;
        for (let i = 0; i < data.length; i++) {
          const v = (data[i] - 128) / 128;
          sum += v * v;
        }
        const rms = Math.sqrt(sum / data.length);
        const level = Math.min(1, Math.max(0.05, rms * 3));
        this.levels = [...this.levels.slice(1), level];
        this.meterFrame = requestAnimationFrame(tick);
      };
      this.meterFrame = requestAnimationFrame(tick);
    } catch {
      // Meter is decoration; recording proceeds without it.
    }
  }

  @action
  stop() {
    clearInterval(this.timer);
    this.timer = null;
    if (this.meterFrame) {
      cancelAnimationFrame(this.meterFrame);
      this.meterFrame = null;
    }
    if (this.recorder && this.recorder.state !== "inactive") {
      this.recorder.stop();
    }
  }

  finishRecording() {
    this.stream?.getTracks().forEach((t) => t.stop());
    this.stream = null;
    this.audioCtx?.close?.();
    this.audioCtx = null;
    this.analyser = null;

    if (!this.chunks.length || this.elapsed < 0.5) {
      this.fail("disteleplus.voice.errors.too_short");
      return;
    }
    this.blob = new Blob(this.chunks, { type: this.type.mime.split(";")[0] });
    this.previewUrl = URL.createObjectURL(this.blob);
    this.state = "preview";
  }

  @action
  discard() {
    this.teardown();
    this.blob = null;
    this.chunks = [];
    this.elapsed = 0;
    this.state = "idle";
  }

  @action
  async send() {
    if (!this.blob) {
      return;
    }
    this.state = "uploading";
    const filename = `voice-note-${stamp()}.${this.type.ext}`;
    const form = new FormData();
    form.append("type", "chat-composer");
    form.append("file", this.blob, filename);

    try {
      const upload = await ajax("/uploads.json", {
        type: "POST",
        data: form,
        processData: false,
        contentType: false,
      });
      if (!upload?.id) {
        throw new Error(upload?.errors?.join(", ") || "upload failed");
      }

      const payload = { message: "", upload_ids: [upload.id] };
      if (this.args.model.threadId) {
        payload.thread_id = this.args.model.threadId;
      }
      await ajax(`/chat/api/channels/${this.args.model.channelId}/messages`, {
        type: "POST",
        data: payload,
      });

      this.state = "sent";
      this.args.closeModal();
    } catch (e) {
      this.state = "preview";
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @title={{this.title}}
      @closeModal={{@closeModal}}
      class="disteleplus-voice-modal"
    >
      <:body>
        {{#if this.isError}}
          <div class="disteleplus-voice__error">
            {{icon "triangle-exclamation"}}
            <p>{{this.errorMessage}}</p>
          </div>
        {{else if this.isPreview}}
          <div class="disteleplus-voice__preview">
            <p class="disteleplus-voice__hint">
              {{i18n
                "disteleplus.voice.preview_hint"
                duration=this.elapsedLabel
              }}
            </p>
            <audio
              class="disteleplus-voice__preview-audio"
              controls
              preload="auto"
              src={{this.previewUrl}}
            ></audio>
          </div>
        {{else if this.isUploading}}
          <div class="disteleplus-voice__uploading">
            {{icon "spinner" class="loading-icon"}}
            <p>{{i18n "disteleplus.voice.sending"}}</p>
          </div>
        {{else}}
          <div
            class="disteleplus-voice__stage
              {{if this.isRecording 'is-recording'}}
              {{if this.nearLimit 'is-near-limit'}}"
          >
            <div class="disteleplus-voice__meter" aria-hidden="true">
              {{#each this.meterStyle as |height|}}
                <span style={{htmlSafe (concat "height:" height)}}></span>
              {{/each}}
            </div>
            <div class="disteleplus-voice__clock">
              <span
                class="disteleplus-voice__elapsed"
              >{{this.elapsedLabel}}</span>
              <span class="disteleplus-voice__max">/ {{this.maxLabel}}</span>
            </div>
            <p class="disteleplus-voice__hint">
              {{#if this.isRecording}}
                {{i18n "disteleplus.voice.recording_hint"}}
              {{else if this.isRequesting}}
                {{i18n "disteleplus.voice.requesting"}}
              {{else}}
                {{i18n "disteleplus.voice.idle_hint"}}
              {{/if}}
            </p>
          </div>
        {{/if}}
      </:body>

      <:footer>
        {{#if this.isError}}
          <DButton
            @action={{this.discard}}
            @label="disteleplus.voice.try_again"
            @icon="rotate"
            class="btn-primary"
          />
          <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
        {{else if this.isPreview}}
          <DButton
            @action={{this.send}}
            @label="disteleplus.voice.send"
            @icon="paper-plane"
            class="btn-primary disteleplus-voice__send"
          />
          <DButton
            @action={{this.discard}}
            @label="disteleplus.voice.rerecord"
            @icon="rotate"
            class="btn-default"
          />
          <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
        {{else if this.isRecording}}
          <DButton
            @action={{this.stop}}
            @label="disteleplus.voice.stop"
            @icon="stop"
            class="btn-danger disteleplus-voice__stop"
          />
          <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
        {{else if this.isUploading}}
          <DButton
            @label="disteleplus.voice.sending"
            @disabled={{true}}
            class="btn-primary"
          />
        {{else}}
          <DButton
            @action={{this.start}}
            @label="disteleplus.voice.start"
            @icon="microphone"
            @disabled={{this.isRequesting}}
            class="btn-primary disteleplus-voice__start"
          />
          <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
