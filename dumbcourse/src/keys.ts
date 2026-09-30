// Normalises key presses across engines: modern `key` names, the older
// "Up"/"Down" spellings, keyCode-only engines, KaiOS soft keys and the
// phone keypad (0–9, *, #).

export type Key =
  | "up"
  | "down"
  | "left"
  | "right"
  | "enter"
  | "back"
  | "escape"
  | "softleft"
  | "softright"
  | "menu"
  | "0"
  | "1"
  | "2"
  | "3"
  | "4"
  | "5"
  | "6"
  | "7"
  | "8"
  | "9"
  | "*"
  | "#"
  | "?";

const BY_KEY: Record<string, Key> = {
  ArrowUp: "up",
  Up: "up",
  ArrowDown: "down",
  Down: "down",
  ArrowLeft: "left",
  Left: "left",
  ArrowRight: "right",
  Right: "right",
  Enter: "enter",
  Accept: "enter",
  Backspace: "back",
  BrowserBack: "back",
  GoBack: "back",
  Escape: "escape",
  Esc: "escape",
  SoftLeft: "softleft",
  F1: "softleft",
  SoftRight: "softright",
  F2: "softright",
  ContextMenu: "menu",
  "*": "*",
  "#": "#",
  "?": "?",
};

const BY_CODE: Record<number, Key> = {
  38: "up",
  40: "down",
  37: "left",
  39: "right",
  13: "enter",
  8: "back",
  27: "escape",
  112: "softleft",
  113: "softright",
  93: "menu",
  106: "*",
};

export function keyOf(e: KeyboardEvent): Key | null {
  if (e.ctrlKey || e.metaKey || e.altKey) return null;
  const name = e.key;
  if (name && name !== "Unidentified") {
    if (BY_KEY[name]) return BY_KEY[name];
    if (name.length === 1 && name >= "0" && name <= "9") return name as Key;
    return null;
  }
  const code = e.keyCode || e.which;
  if (BY_CODE[code]) return BY_CODE[code];
  if (code >= 48 && code <= 57) {
    if (e.shiftKey && code === 56) return "*";
    if (e.shiftKey && code === 51) return "#";
    return String(code - 48) as Key;
  }
  if (code >= 96 && code <= 105) return String(code - 96) as Key;
  return null;
}

export function isTypingTarget(el: Element | null): boolean {
  if (!el) return false;
  const tag = el.tagName;
  if (tag === "TEXTAREA" || tag === "SELECT") return true;
  if (tag === "INPUT") {
    const type = ((el as HTMLInputElement).type || "text").toLowerCase();
    return (
      [
        "checkbox",
        "radio",
        "button",
        "submit",
        "reset",
        "range",
        "file",
        "color",
      ].indexOf(type) < 0
    );
  }
  return (el as HTMLElement).isContentEditable === true;
}
