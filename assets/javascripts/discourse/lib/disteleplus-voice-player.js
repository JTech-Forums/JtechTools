// Disteleplus voice-note player.
//
// Replaces the browser's default <audio controls> in native messages with a
// messenger-style player: round play button, a waveform you can click or
// drag to seek, "elapsed / total", a speed toggle and a download link.
//
// Glimmer re-renders uploads freely, so this NEVER moves or re-parents the <audio>. The native element
// stays exactly where Glimmer put it (visually hidden) and the player is
// inserted as its next sibling; a registry keyed on the audio node, plus the
// observer's removedNodes, tears the player down the moment Glimmer drops
// the audio, so re-renders never stack duplicate players.
//
// Waveform: the file is fetched once and decoded with WebAudio to real peaks
// (cached per URL). Uploads on an S3/CDN host without CORS cannot be decoded
// by the browser, so that failure falls back to a deterministic pattern
// seeded from the URL — stable per file, clearly a pattern, never a broken
// control. Only one note plays at a time.
import { i18n } from "discourse-i18n";

export const ENHANCED_CLASS = "disteleplus-audio--enhanced";

const BAR_COUNT = 40;
const SPEEDS = [1, 1.5, 2];
const SPEED_STORAGE_KEY = "disteleplus-voice-speed";
const VOICE_NAME = /(^|\/)voice(-note)?[-_.]/i;

const peaksCache = new Map();
const players = new Map(); // audio element → VoicePlayer
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

export function formatTime(seconds) {
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

// Reduces a decoded buffer to BAR_COUNT normalised peaks (0.12–1).
export function reducePeaks(buffer, barCount = BAR_COUNT) {
  const channels = buffer.numberOfChannels;
  const length = buffer.length;
  const window = Math.max(1, Math.floor(length / barCount));
  const peaks = new Array(barCount).fill(0);

  for (let c = 0; c < channels; c++) {
    const data = buffer.getChannelData(c);
    for (let i = 0; i < barCount; i++) {
      const start = i * window;
      const end = Math.min(length, start + window);
      let peak = 0;
      for (let j = start; j < end; j += 4) {
        const v = Math.abs(data[j]);
        if (v > peak) {
          peak = v;
        }
      }
      peaks[i] = Math.max(peaks[i], peak);
    }
  }
  return normalisePeaks(peaks);
}

export function normalisePeaks(peaks) {
  const max = Math.max(...peaks, 0.001);
  return peaks.map((p) => Math.max(0.12, Math.min(1, p / max)));
}

// Deterministic, speech-shaped pattern for files the browser cannot decode.
function patternPeaks(seedText, barCount = BAR_COUNT) {
  // Small LCG seeded from the URL — arithmetic only, no bitwise ops.
  const MOD = 4294967296;
  let h = 2166136261;
  for (let i = 0; i < seedText.length; i++) {
    h = (h * 31 + seedText.charCodeAt(i)) % MOD;
  }
  const out = [];
  for (let i = 0; i < barCount; i++) {
    h = (h * 1103515245 + 12345) % MOD;
    const noise = Math.floor(h / 256) / 16777216;
    // Two slow envelopes so it reads as phrases, not static.
    const phrase =
      0.55 + 0.45 * Math.sin(i / 3.1 + (h % 7)) * Math.sin(i / 7.3);
    out.push(0.18 + 0.82 * Math.abs(phrase) * (0.55 + 0.45 * noise));
  }
  return normalisePeaks(out);
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

// Builds the shared waveform track DOM. Used by the chat player and by the
// recorder's preview so both look identical.
export function buildTrack(barCount = BAR_COUNT) {
  const track = el("div", "disteleplus-wave", {
    role: "slider",
    tabindex: "0",
    "aria-valuemin": "0",
    "aria-valuemax": "100",
    "aria-valuenow": "0",
  });
  const bars = [];
  for (let i = 0; i < barCount; i++) {
    const bar = el("span", "disteleplus-wave__bar");
    bar.style.setProperty("--peak", "0.3");
    track.appendChild(bar);
    bars.push(bar);
  }
  return { track, bars };
}

export function paintBars(bars, ratio) {
  const active = Math.round(ratio * bars.length);
  bars.forEach((bar, index) =>
    bar.classList.toggle("is-played", index < active)
  );
}

export function applyPeaks(bars, peaks) {
  peaks.forEach((peak, index) => {
    bars[index]?.style.setProperty("--peak", peak.toFixed(3));
  });
}

class VoicePlayer {
  constructor(audio, { voice }) {
    this.audio = audio;
    this.voice = voice;
    this.speed = readSpeed();
    this.duration = Number.isFinite(audio.duration) ? audio.duration : 0;
    this.scrubbing = false;
    this.src =
      audio.currentSrc || audio.src || audio.querySelector("source")?.src || "";
    this.build();
    this.bind();
    this.audio.playbackRate = this.speed;
    this.paint();
    loadPeaks(this.src)
      .then(({ peaks, duration }) => {
        applyPeaks(this.bars, peaks);
        this.root.classList.add("disteleplus-audio--decoded");
        if (!this.duration && duration) {
          this.duration = duration;
          this.paint();
        }
      })
      .catch(() => {
        applyPeaks(this.bars, patternPeaks(this.src));
        this.root.classList.add("disteleplus-audio--pattern");
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

    this.playButton = el("button", "disteleplus-audio__play", {
      type: "button",
      "aria-label": i18n("disteleplus.player.play"),
    });
    this.playButton.appendChild(svgIcon("play"));

    const { track, bars } = buildTrack();
    this.track = track;
    this.bars = bars;
    this.track.setAttribute("aria-label", i18n("disteleplus.player.seek"));

    this.meta = el("div", "disteleplus-audio__meta");
    this.time = el("span", "disteleplus-audio__time");
    this.time.textContent = `0:00 / ${formatTime(this.duration)}`;

    this.speedButton = el("button", "disteleplus-audio__speed", {
      type: "button",
      title: i18n("disteleplus.player.speed"),
    });

    this.download = el("a", "disteleplus-audio__download", {
      href: this.src,
      download: "",
      title: i18n("disteleplus.player.download"),
      "aria-label": i18n("disteleplus.player.download"),
    });
    this.download.appendChild(svgIcon("download"));

    this.kind = el("span", "disteleplus-audio__kind", { title: label });
    this.kind.appendChild(svgIcon(this.voice ? "microphone" : "music"));

    this.meta.append(this.kind, this.time, this.speedButton, this.download);

    this.body = el("div", "disteleplus-audio__body");
    this.body.append(this.track, this.meta);
    this.root.append(this.playButton, this.body);

    this.audio.removeAttribute("controls");
    this.audio.classList.add("disteleplus-audio__native");
    this.audio.insertAdjacentElement("afterend", this.root);
  }

  bind() {
    this.playButton.addEventListener("click", () => this.toggle());
    this.speedButton.addEventListener("click", () => this.cycleSpeed());

    const syncDuration = () => {
      if (Number.isFinite(this.audio.duration) && this.audio.duration > 0) {
        this.duration = this.audio.duration;
        this.paint();
      }
    };
    this.audio.addEventListener("loadedmetadata", syncDuration);
    this.audio.addEventListener("durationchange", syncDuration);
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
      // First play of a voice note = "listened" — announced once via a
      // bubbling event so the conversation can record the receipt without
      // the player knowing anything about messages or ajax.
      if (this.voice && !this.announcedListen) {
        this.announcedListen = true;
        this.root.dispatchEvent(
          new CustomEvent("disteleplus:voice-played", { bubbles: true })
        );
      }
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
      this.audio.play()?.catch?.(() => {
        this.root.classList.add("disteleplus-audio--error");
      });
    } else {
      this.audio.pause();
    }
  }

  cycleSpeed() {
    this.speed = SPEEDS[(SPEEDS.indexOf(this.speed) + 1) % SPEEDS.length];
    this.audio.playbackRate = this.speed;
    storeSpeed(this.speed);
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
      // Metadata not ready yet; the next timeupdate repaints.
    }
    this.paint();
  }

  paint() {
    const position = this.audio.currentTime || 0;
    const ratio = this.duration ? Math.min(1, position / this.duration) : 0;
    this.paintProgress(ratio, position);
    this.paintSpeed();
  }

  paintProgress(ratio, position) {
    this.root.style.setProperty("--progress", ratio.toFixed(4));
    this.track.setAttribute("aria-valuenow", String(Math.round(ratio * 100)));
    const label = `${formatTime(position)} / ${formatTime(this.duration)}`;
    this.track.setAttribute("aria-valuetext", label);
    this.time.textContent = label;
    paintBars(this.bars, ratio);
  }

  paintSpeed() {
    this.speedButton.textContent = `${this.speed}×`;
    this.speedButton.setAttribute(
      "aria-label",
      i18n("disteleplus.player.speed_value", { speed: this.speed })
    );
    this.speedButton.classList.toggle("is-default", this.speed === 1);
  }

  destroy() {
    if (current === this) {
      current = null;
    }
    this.root.remove();
  }
}

// Wraps one <audio>. Idempotent — a second call on the same node is a no-op.
export function enhanceAudio(audio, { allAudio }) {
  if (!(audio instanceof HTMLAudioElement)) {
    return false;
  }
  if (players.has(audio) || audio.classList.contains(ENHANCED_CLASS)) {
    return false;
  }
  const src =
    audio.currentSrc || audio.src || audio.querySelector("source")?.src;
  if (!src) {
    return false;
  }
  // Served upload URLs are sha-named, so the filename test never matches
  // them — the template stamps data-voice from the original filename.
  const voice = audio.dataset.voice === "1" || isVoiceNoteSource(src);
  if (!voice && !allAudio) {
    return false;
  }
  audio.classList.add(ENHANCED_CLASS);
  const player = new VoicePlayer(audio, { voice });
  players.set(audio, player);
  audio
    .closest(".disteleplus-upload")
    ?.classList.add(
      voice ? "disteleplus-has-voice-note" : "disteleplus-has-audio"
    );
  return true;
}

// Finds every not-yet-enhanced native conversation audio element under `root`.
export function enhanceWithin(root, options) {
  if (!root?.querySelectorAll) {
    return 0;
  }
  let count = 0;
  const nodes =
    root instanceof HTMLAudioElement ? [root] : root.querySelectorAll("audio");
  nodes.forEach((audio) => {
    if (!audio.closest(".disteleplus-message, .disteleplus-voice-modal")) {
      return;
    }
    if (enhanceAudio(audio, options)) {
      count++;
    }
  });
  return count;
}

// Tears down players whose <audio> Glimmer has removed from the document.
export function pruneDetached() {
  for (const [audio, player] of players) {
    if (!audio.isConnected) {
      player.destroy();
      players.delete(audio);
    }
  }
}
