// Disteleplus voice-note player.
//
// Replaces the browser's default <audio controls> in chat messages with a
// compact, theme-aware player: play/pause, a real waveform you can click or
// drag to seek, elapsed/total time, and a playback-speed toggle. Pure DOM —
// it wraps the existing <audio> element (which keeps doing the actual
// playing, so nothing about upload URLs, secure media or CDN changes) and
// hides it visually.
//
// The waveform is computed client-side: the file is fetched once, decoded
// with WebAudio, reduced to BAR_COUNT peak samples and cached per URL. Until
// that resolves (or if it fails — CORS, an odd codec, no AudioContext) the
// bars render at a neutral height and the player is fully usable as a plain
// progress bar. Only one note plays at a time; starting another pauses the
// current one, the way every messaging app behaves.
import { i18n } from "discourse-i18n";

export const ENHANCED_CLASS = "disteleplus-audio--enhanced";

const BAR_COUNT = 44;
const SPEEDS = [1, 1.5, 2];
const SPEED_STORAGE_KEY = "disteleplus-voice-speed";
const VOICE_NAME = /(^|\/)voice(-note)?[-_.]/i;

const peaksCache = new Map();
let current = null;

export function isVoiceNoteSource(src) {
  if (!src) {
    return false;
  }
  try {
    const path = new URL(src, window.location.origin).pathname;
    return VOICE_NAME.test(decodeURIComponent(path));
  } catch {
    return VOICE_NAME.test(src);
  }
}

function formatTime(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) {
    return "0:00";
  }
  const whole = Math.round(seconds);
  const minutes = Math.floor(whole / 60);
  const rest = whole % 60;
  return `${minutes}:${rest < 10 ? "0" : ""}${rest}`;
}

function readSpeed() {
  try {
    const stored = parseFloat(localStorage.getItem(SPEED_STORAGE_KEY));
    return SPEEDS.includes(stored) ? stored : 1;
  } catch {
    return 1;
  }
}

function storeSpeed(speed) {
  try {
    localStorage.setItem(SPEED_STORAGE_KEY, String(speed));
  } catch {
    // Storage blocked — the toggle still works for this page.
  }
}

function el(tag, className, attrs = {}) {
  const node = document.createElement(tag);
  if (className) {
    node.className = className;
  }
  for (const [key, value] of Object.entries(attrs)) {
    node.setAttribute(key, value);
  }
  return node;
}

function svgIcon(name) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("class", `fa d-icon d-icon-${name} svg-icon svg-string`);
  svg.setAttribute("aria-hidden", "true");
  const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
  use.setAttribute("href", `#${name}`);
  svg.appendChild(use);
  return svg;
}

// Downmixes to mono, slices into BAR_COUNT windows, takes each window's peak,
// then normalises so the loudest bar fills the track. Short notes are
// upsampled so a 2-second clip still draws all bars.
function reducePeaks(buffer) {
  const channels = buffer.numberOfChannels;
  const length = buffer.length;
  const window = Math.max(1, Math.floor(length / BAR_COUNT));
  const peaks = new Array(BAR_COUNT).fill(0);

  for (let c = 0; c < channels; c++) {
    const data = buffer.getChannelData(c);
    for (let i = 0; i < BAR_COUNT; i++) {
      const start = i * window;
      const end = Math.min(length, start + window);
      let peak = 0;
      for (let j = start; j < end; j += 8) {
        const v = Math.abs(data[j]);
        if (v > peak) {
          peak = v;
        }
      }
      if (peak > peaks[i]) {
        peaks[i] = peak;
      }
    }
  }

  const max = Math.max(...peaks, 0.001);
  return peaks.map((p) => Math.max(0.08, p / max));
}

async function loadPeaks(src) {
  if (peaksCache.has(src)) {
    return peaksCache.get(src);
  }
  const promise = (async () => {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) {
      throw new Error("no AudioContext");
    }
    const response = await fetch(src, { credentials: "same-origin" });
    if (!response.ok) {
      throw new Error(`fetch ${response.status}`);
    }
    const bytes = await response.arrayBuffer();
    const ctx = new AudioCtx();
    try {
      const decoded = await ctx.decodeAudioData(bytes);
      return { peaks: reducePeaks(decoded), duration: decoded.duration };
    } finally {
      ctx.close?.();
    }
  })();
  peaksCache.set(src, promise);
  promise.catch(() => peaksCache.delete(src));
  return promise;
}

class VoicePlayer {
  constructor(audio, { voice }) {
    this.audio = audio;
    this.voice = voice;
    this.speed = readSpeed();
    this.duration = Number.isFinite(audio.duration) ? audio.duration : 0;
    this.scrubbing = false;
    this.build();
    this.bind();
    this.audio.playbackRate = this.speed;
    this.paint();
    loadPeaks(this.audio.currentSrc || this.audio.src)
      .then(({ peaks, duration }) => {
        this.applyPeaks(peaks);
        if (!this.duration && duration) {
          this.duration = duration;
          this.paint();
        }
      })
      .catch(() => {
        this.root.classList.add("disteleplus-audio--flat");
      });
  }

  build() {
    const label = this.voice
      ? i18n("disteleplus.player.voice_note")
      : i18n("disteleplus.player.audio");

    this.root = el(
      "div",
      `disteleplus-audio ${this.voice ? "disteleplus-audio--voice" : "disteleplus-audio--file"}`,
      { role: "group", "aria-label": label }
    );

    this.playButton = el("button", "disteleplus-audio__play btn-flat", {
      type: "button",
      "aria-label": i18n("disteleplus.player.play"),
    });
    this.playButton.appendChild(svgIcon("play"));

    this.kind = el("span", "disteleplus-audio__kind");
    this.kind.appendChild(svgIcon(this.voice ? "microphone" : "music"));
    this.kind.title = label;

    this.track = el("div", "disteleplus-audio__track", {
      role: "slider",
      tabindex: "0",
      "aria-label": i18n("disteleplus.player.seek"),
      "aria-valuemin": "0",
      "aria-valuemax": "100",
      "aria-valuenow": "0",
    });
    this.bars = [];
    for (let i = 0; i < BAR_COUNT; i++) {
      const bar = el("span", "disteleplus-audio__bar");
      bar.style.setProperty("--peak", "0.35");
      this.track.appendChild(bar);
      this.bars.push(bar);
    }

    this.time = el("span", "disteleplus-audio__time");
    this.elapsed = el("span", "disteleplus-audio__elapsed");
    this.total = el("span", "disteleplus-audio__total");
    this.time.append(this.elapsed, this.total);

    this.speedButton = el("button", "disteleplus-audio__speed btn-flat", {
      type: "button",
      title: i18n("disteleplus.player.speed"),
    });

    const link = this.audio.currentSrc || this.audio.src;
    this.download = el("a", "disteleplus-audio__download", {
      href: link,
      download: "",
      title: i18n("disteleplus.player.download"),
      "aria-label": i18n("disteleplus.player.download"),
    });
    this.download.appendChild(svgIcon("download"));

    this.root.append(
      this.playButton,
      this.kind,
      this.track,
      this.time,
      this.speedButton,
      this.download
    );

    this.audio.removeAttribute("controls");
    this.audio.classList.add("disteleplus-audio__native");
    this.audio.parentNode.insertBefore(this.root, this.audio);
    this.root.appendChild(this.audio);
  }

  bind() {
    this.playButton.addEventListener("click", () => this.toggle());
    this.speedButton.addEventListener("click", () => this.cycleSpeed());

    this.audio.addEventListener("loadedmetadata", () => {
      if (Number.isFinite(this.audio.duration)) {
        this.duration = this.audio.duration;
      }
      this.paint();
    });
    this.audio.addEventListener("durationchange", () => {
      if (Number.isFinite(this.audio.duration)) {
        this.duration = this.audio.duration;
        this.paint();
      }
    });
    this.audio.addEventListener("timeupdate", () => {
      if (!this.scrubbing) {
        this.paint();
      }
    });
    this.audio.addEventListener("play", () => {
      if (current && current !== this) {
        current.audio.pause();
      }
      current = this;
      this.root.classList.add("disteleplus-audio--playing");
      this.setPlayIcon("pause");
    });
    this.audio.addEventListener("pause", () => {
      this.root.classList.remove("disteleplus-audio--playing");
      this.setPlayIcon("play");
    });
    this.audio.addEventListener("ended", () => {
      this.root.classList.remove("disteleplus-audio--playing");
      this.setPlayIcon("play");
      this.audio.currentTime = 0;
      this.paint();
    });
    this.audio.addEventListener("error", () => {
      this.root.classList.add("disteleplus-audio--error");
      this.playButton.disabled = true;
      this.playButton.title = i18n("disteleplus.player.unavailable");
    });

    // Pointer scrubbing — press, drag, release. Pointer capture keeps the
    // drag alive when the cursor leaves the (small) track.
    this.track.addEventListener("pointerdown", (event) => {
      event.preventDefault();
      this.scrubbing = true;
      this.track.setPointerCapture?.(event.pointerId);
      this.seekToEvent(event, false);
    });
    this.track.addEventListener("pointermove", (event) => {
      if (this.scrubbing) {
        this.seekToEvent(event, false);
      }
    });
    const finish = (event) => {
      if (!this.scrubbing) {
        return;
      }
      this.scrubbing = false;
      this.seekToEvent(event, true);
    };
    this.track.addEventListener("pointerup", finish);
    this.track.addEventListener("pointercancel", finish);

    this.track.addEventListener("keydown", (event) => {
      const step = 5;
      if (event.key === "ArrowRight" || event.key === "ArrowUp") {
        event.preventDefault();
        this.seek(this.audio.currentTime + step);
      } else if (event.key === "ArrowLeft" || event.key === "ArrowDown") {
        event.preventDefault();
        this.seek(this.audio.currentTime - step);
      } else if (event.key === "Home") {
        event.preventDefault();
        this.seek(0);
      } else if (event.key === "End") {
        event.preventDefault();
        this.seek(this.duration);
      } else if (event.key === " " || event.key === "Enter") {
        event.preventDefault();
        this.toggle();
      }
    });
  }

  setPlayIcon(name) {
    this.playButton.replaceChildren(svgIcon(name));
    this.playButton.setAttribute(
      "aria-label",
      i18n(`disteleplus.player.${name}`)
    );
  }

  toggle() {
    if (this.audio.paused) {
      const attempt = this.audio.play();
      attempt?.catch?.(() => {
        this.root.classList.add("disteleplus-audio--error");
      });
    } else {
      this.audio.pause();
    }
  }

  cycleSpeed() {
    const next = SPEEDS[(SPEEDS.indexOf(this.speed) + 1) % SPEEDS.length];
    this.speed = next;
    this.audio.playbackRate = next;
    storeSpeed(next);
    this.paintSpeed();
  }

  seekToEvent(event, commit) {
    const rect = this.track.getBoundingClientRect();
    if (!rect.width) {
      return;
    }
    const ratio = Math.min(
      1,
      Math.max(0, (event.clientX - rect.left) / rect.width)
    );
    const target = ratio * (this.duration || 0);
    if (commit) {
      this.seek(target);
    } else {
      this.paintProgress(ratio, target);
    }
  }

  seek(seconds) {
    if (!this.duration) {
      return;
    }
    const clamped = Math.min(this.duration, Math.max(0, seconds));
    try {
      this.audio.currentTime = clamped;
    } catch {
      // Metadata not ready yet; the next timeupdate will repaint.
    }
    this.paint();
  }

  applyPeaks(peaks) {
    peaks.forEach((peak, index) => {
      this.bars[index]?.style.setProperty("--peak", peak.toFixed(3));
    });
    this.root.classList.add("disteleplus-audio--waveform");
  }

  paint() {
    const position = this.audio.currentTime || 0;
    const ratio = this.duration ? Math.min(1, position / this.duration) : 0;
    this.paintProgress(ratio, position);
    this.paintSpeed();
  }

  paintProgress(ratio, position) {
    const percent = Math.round(ratio * 100);
    this.root.style.setProperty("--progress", ratio.toFixed(4));
    this.track.setAttribute("aria-valuenow", String(percent));
    this.track.setAttribute(
      "aria-valuetext",
      `${formatTime(position)} / ${formatTime(this.duration)}`
    );
    const showElapsed =
      position > 0.25 ||
      this.root.classList.contains("disteleplus-audio--playing");
    this.elapsed.textContent = showElapsed ? formatTime(position) : "";
    this.elapsed.hidden = !showElapsed;
    this.total.textContent = formatTime(this.duration);
    const active = Math.round(ratio * BAR_COUNT);
    this.bars.forEach((bar, index) => {
      bar.classList.toggle("is-played", index < active);
    });
  }

  paintSpeed() {
    this.speedButton.textContent = `${this.speed}×`;
    this.speedButton.setAttribute(
      "aria-label",
      i18n("disteleplus.player.speed_value", { speed: this.speed })
    );
    this.speedButton.classList.toggle("is-default", this.speed === 1);
  }
}

// Wraps one <audio>. Idempotent — a second call on the same node is a no-op.
export function enhanceAudio(audio, { allAudio }) {
  if (!(audio instanceof HTMLAudioElement)) {
    return false;
  }
  if (audio.classList.contains(ENHANCED_CLASS)) {
    return false;
  }
  const src =
    audio.currentSrc || audio.src || audio.querySelector("source")?.src;
  const voice = isVoiceNoteSource(src);
  if (!voice && !allAudio) {
    return false;
  }
  if (!src) {
    return false;
  }
  audio.classList.add(ENHANCED_CLASS);
  // Kept on the element so devtools (and a future teardown) can reach it.
  audio.disteleplusPlayer = new VoicePlayer(audio, { voice });
  return true;
}

// Finds every not-yet-enhanced chat audio element under `root`.
export function enhanceWithin(root, options) {
  if (!root?.querySelectorAll) {
    return 0;
  }
  let count = 0;
  const nodes =
    root instanceof HTMLAudioElement ? [root] : root.querySelectorAll("audio");
  nodes.forEach((audio) => {
    if (
      !audio.closest(".chat-message, .chat-message-container, .chat-thread")
    ) {
      return;
    }
    if (enhanceAudio(audio, options)) {
      count++;
    }
  });
  return count;
}
