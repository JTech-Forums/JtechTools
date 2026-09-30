// The soft-key bar along the bottom, like a feature phone's own apps:
// the label over each soft key (left, centre/OK, right) says what it does
// right now. The labels are tappable too, for touch screens.

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
