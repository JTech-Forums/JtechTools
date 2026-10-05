// The recordings the composer's voice recorder makes (setting voice_recorder):
// the first container the browser can record that Discourse plays as audio.
// Safari and Chrome 126+ record MP4 (.m4a), Firefox Ogg; WebM is the last
// resort, which Discourse shows with a video player.
export interface VoiceFormat {
  mime: string;
  ext: string;
}

const FORMATS: VoiceFormat[] = [
  { mime: "audio/mp4", ext: "m4a" },
  { mime: "audio/ogg;codecs=opus", ext: "ogg" },
  { mime: "audio/webm;codecs=opus", ext: "webm" },
];

// Speech at this rate is clear and keeps a minute under half a megabyte.
export const VOICE_BITRATE = 64000;

export function voiceFormat(): VoiceFormat | null {
  if (
    typeof MediaRecorder === "undefined" ||
    !navigator.mediaDevices?.getUserMedia
  ) {
    return null;
  }
  return FORMATS.find((f) => MediaRecorder.isTypeSupported(f.mime)) ?? null;
}

export function clock(seconds: number) {
  const m = Math.floor(seconds / 60);
  const s = String(seconds % 60).padStart(2, "0");
  return `${m}:${s}`;
}
