// Emoji as the forum's own images (the same set the full site uses), so
// they look right even on phones whose fonts predate modern emoji.

import { settings } from "../config.ts";
import { get } from "../api.ts";
import { escapeHtml, html, raw, type SafeHtml } from "../html.ts";
import { getJson, setJson } from "../storage.ts";

export function emojiUrl(name: string): string {
  const custom = settings.customEmojis[name];
  if (custom) return custom;
  const path = name.replace(/:t(\d)$/, "/$1");
  return settings.emojiUrl.replace(
    "EMOJINAME",
    encodeURIComponent(path).replace(/%2F/g, "/")
  );
}

export function emojiImg(name: string, cls = "emoji"): SafeHtml {
  return html`<img
    class="${cls}"
    src="${emojiUrl(name)}"
    alt=":${name}:"
    title=":${name}:"
    width="20"
    height="20"
  />`;
}

const SHORTCODE = /:([a-z0-9_+-]+(?::t\d)?):/gi;

// Escapes text, then turns :shortcodes: into emoji images. Topic titles and
// notification text arrive with shortcodes unconverted.
export function emojify(text: string | null | undefined): SafeHtml {
  const escaped = escapeHtml(text || "");
  return raw(
    escaped.replace(SHORTCODE, (m, name: string) => {
      if (name.length > 60) return m;
      return emojiImg(name.toLowerCase()).value;
    })
  );
}

// A friendly default grid for the composer picker.
export const COMMON_EMOJI = [
  "+1",
  "heart",
  "smile",
  "joy",
  "slightly_smiling_face",
  "wink",
  "blush",
  "pray",
  "clap",
  "raised_hands",
  "muscle",
  "ok_hand",
  "wave",
  "thinking",
  "sweat_smile",
  "rofl",
  "heart_eyes",
  "star_struck",
  "sunglasses",
  "innocent",
  "hugs",
  "partying_face",
  "cry",
  "sob",
  "angry",
  "scream",
  "exploding_head",
  "face_with_rolling_eyes",
  "grimacing",
  "neutral_face",
  "-1",
  "100",
  "fire",
  "tada",
  "sparkles",
  "star",
  "white_check_mark",
  "x",
  "warning",
  "bulb",
  "rocket",
  "eyes",
  "handshake",
  "point_up",
  "point_right",
  "iphone",
  "mobile_phone_off",
  "books",
];

let names: string[] | null = null;

// The full list of emoji names, for the picker's search. Fetched once, on
// first search, and kept.
export function allEmojiNames(): Promise<string[]> {
  if (names) return Promise.resolve(names);
  const cached = getJson<string[] | null>("emoji-names", null);
  if (cached && cached.length) {
    names = cached;
    return Promise.resolve(cached);
  }
  return get<{ map: Record<string, string> }>(
    settings.basePath + "/emoji_map.json"
  ).then((d) => {
    const list: string[] = [];
    const map = (d && d.map) || {};
    for (const k in map) if (map.hasOwnProperty(k)) list.push(k);
    for (const k in settings.customEmojis)
      if (settings.customEmojis.hasOwnProperty(k) && list.indexOf(k) < 0)
        list.push(k);
    list.sort();
    names = list;
    setJson("emoji-names", list);
    return list;
  });
}

export function searchEmoji(all: string[], term: string, limit = 40): string[] {
  const t = term.toLowerCase().replace(/^:|:$/g, "");
  if (!t) return [];
  const starts: string[] = [];
  const contains: string[] = [];
  for (let i = 0; i < all.length; i++) {
    const idx = all[i].indexOf(t);
    if (idx === 0) starts.push(all[i]);
    else if (idx > 0) contains.push(all[i]);
    if (starts.length >= limit) break;
  }
  return starts.concat(contains).slice(0, limit);
}
