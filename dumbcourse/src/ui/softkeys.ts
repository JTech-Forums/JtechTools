// The soft-key bar along the bottom, like a feature phone's own apps:
// the label over each soft key (left, centre/OK, right) says what it does
// right now. The labels are tappable too, for touch screens.
//
// The Android app (JTech-Forums/jtech-dpad-apk, assets/softkeys.js) draws
// its own native bar on keypad phones by reading this one, so its users get
// soft-key changes without an app update. It relies on: #softkeys being a
// child of <body>; one button per slot with data-sk="left|center|right" and
// its label as plain text; a click on a button running its handler (the app
// presses the soft keys that way); the "softkeys" value in dc:prefs; the
// light/dark class on <html>; and --sk-h for every offset the bar needs.
// Changing any of those needs a matching app release.

import { byId, setHtml } from "../dom.ts";
import { html } from "../html.ts";

export interface Softkeys {
  left: string;
  center: string;
  right: string;
}

let page: Softkeys = { left: "Menu", center: "Select", right: "" };
let layer: Softkeys | null = null;
let handlers: {
  left: () => void;
  center: () => void;
  right: () => void;
} | null = null;

function render(): void {
  const bar = byId("softkeys");
  if (!bar) return;
  const keys = layer || page;
  setHtml(
    bar,
    html`<button type="button" class="sk sk-left" tabindex="-1" data-sk="left">
        ${keys.left}</button
      ><button
        type="button"
        class="sk sk-center"
        tabindex="-1"
        data-sk="center"
      >
        ${keys.center}</button
      ><button type="button" class="sk sk-right" tabindex="-1" data-sk="right">
        ${keys.right}
      </button>`
  );
}

export function setPageSoftkeys(keys: Partial<Softkeys>): void {
  page = {
    left: keys.left !== undefined ? keys.left : "Menu",
    center: keys.center !== undefined ? keys.center : "Select",
    right: keys.right || "",
  };
  render();
}

export function setLayerSoftkeys(keys: Softkeys | null): void {
  layer = keys;
  render();
}

export function currentSoftkeys(): Softkeys {
  return layer || page;
}

export function mountSoftkeys(h: {
  left: () => void;
  center: () => void;
  right: () => void;
}): void {
  handlers = h;
  const bar = byId("softkeys");
  if (!bar) return;
  bar.addEventListener("click", (e) => {
    const t = e.target as HTMLElement;
    const which = t && t.getAttribute ? t.getAttribute("data-sk") : null;
    if (!which || !handlers) return;
    e.preventDefault();
    if (which === "left") handlers.left();
    else if (which === "right") handlers.right();
    else handlers.center();
  });
  render();
}
