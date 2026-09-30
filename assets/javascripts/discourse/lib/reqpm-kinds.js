// REQ-PM contact kinds as the client shows them. Mirrors
// lib/discourse_reqpm/kinds.rb, which is where values are validated — this
// file only decides icons, input types and which links to offer.

export const CUSTOM = "custom";

// Order is the order of the "add a way to reach you" picker.
export const KINDS = [
  { id: "phone", icon: "phone", input: "tel", inputmode: "tel" },
  { id: "sms", icon: "comment-sms", input: "tel", inputmode: "tel" },
  { id: "whatsapp", icon: "fab-whatsapp", input: "tel", inputmode: "tel" },
  { id: "email", icon: "envelope", input: "email", inputmode: "email" },
  { id: "website", icon: "globe", input: "url", inputmode: "url" },
  { id: "telegram", icon: "fab-telegram", input: "text", inputmode: "text" },
  {
    id: "signal",
    icon: "fab-signal-messenger",
    input: "text",
    inputmode: "text",
  },
  { id: "discord", icon: "fab-discord", input: "text", inputmode: "text" },
  { id: CUSTOM, icon: "far-face-smile", input: "text", inputmode: "text" },
];

const BY_ID = Object.fromEntries(KINDS.map((k) => [k.id, k]));

export function kindInfo(id) {
  return BY_ID[id] || BY_ID[CUSTOM];
}

function digits(value) {
  return (value || "").replace(/[^\d]/g, "");
}

function dialable(value) {
  const d = digits(value);
  return (value || "").trim().startsWith("+") ? `+${d}` : d;
}

function looksLikePhone(value) {
  return /^\+?[\d ().-]+$/.test(value || "") && digits(value).length >= 5;
}

export function httpUrl(value) {
  try {
    const url = new URL(value);
    return ["http:", "https:"].includes(url.protocol) ? url.href : null;
  } catch {
    return null;
  }
}

// The one-tap action for a contact method, or null when copying is the only
// sensible thing (e.g. a Discord username). Every href is built from a
// fixed scheme plus a value the server has already validated for its kind.
export function actionFor(method) {
  const value = (method?.value || "").trim();
  if (!value) {
    return null;
  }
  switch (method.kind) {
    case "phone":
      return { href: `tel:${dialable(value)}`, label: "call" };
    case "sms":
      return { href: `sms:${dialable(value)}`, label: "text" };
    case "whatsapp":
      return digits(value).length >= 5
        ? { href: `https://wa.me/${digits(value)}`, label: "chat" }
        : null;
    case "email":
      // No ?, & or # — they would add headers (cc, body…) to the mailto:.
      return /^[^\s@<>"?&#%]+@[^\s@<>"?&#%]+$/.test(value)
        ? { href: `mailto:${value}`, label: "email" }
        : null;
    case "website": {
      const href = httpUrl(value);
      return href ? { href, label: "visit" } : null;
    }
    case "telegram": {
      if (looksLikePhone(value)) {
        return null;
      }
      const handle = value.replace(/^@/, "");
      return /^[A-Za-z0-9_]{4,32}$/.test(handle)
        ? { href: `https://t.me/${handle}`, label: "chat" }
        : null;
    }
    case "signal":
      return looksLikePhone(value) && value.startsWith("+")
        ? { href: `https://signal.me/#p/${dialable(value)}`, label: "chat" }
        : null;
    case CUSTOM: {
      const href = httpUrl(value);
      return href ? { href, label: "open" } : null;
    }
    default:
      return null;
  }
}

export function isExternal(href) {
  return /^https?:/.test(href || "");
}
