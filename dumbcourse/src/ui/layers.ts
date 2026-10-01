// Overlays: bottom sheets (action lists), dialogs (alert/confirm/prompt)
// and the side drawer. Each one takes the D-pad while open, returns focus
// to where it came from when it closes, and gets its own history entry so
// the phone's Back key closes it instead of leaving the screen.

import { removeNode } from "../compat.ts";
import { $, $$, byId, setHtml } from "../dom.ts";
import { html, raw, type HtmlValue, type SafeHtml } from "../html.ts";
import { focus, focusFirst } from "../nav.ts";
import { isLayerState, pushLayerState } from "../router.ts";
import { icon } from "./icons.ts";
import { createLayerHistory } from "./layer-history.ts";
import { setLayerSoftkeys, type Softkeys } from "./softkeys.ts";

export interface Layer {
  el: HTMLElement;
  // Closes it, no questions asked.
  close: () => void;
  // What Close, Back and the backdrop do: asks the layer first (beforeClose).
  requestClose: () => void;
}

interface OpenLayer extends Layer {
  onClose?: () => void;
  // True if the layer took over (e.g. asks to confirm) and stays open.
  beforeClose?: () => boolean;
  returnFocus: HTMLElement | null;
  softkeys?: Softkeys;
}

const stack: OpenLayer[] = [];
let goTo: ((path: string) => void) | null = null;

// The app's navigate(), which knows to drop open layers first.
export function setNavigator(fn: (path: string) => void): void {
  goTo = fn;
}

const layerHistory = createLayerHistory({
  depth: () => stack.length,
  push: pushLayerState,
  go: (delta) => history.go(delta),
  defer: (fn) => {
    void Promise.resolve().then(fn);
  },
});

function host(): HTMLElement {
  let el = byId("layers");
  if (!el) {
    el = document.createElement("div");
    el.id = "layers";
    document.body.appendChild(el);
  }
  return el;
}

function refreshSoftkeys(): void {
  const top = stack[stack.length - 1];
  setLayerSoftkeys(
    top ? top.softkeys || { left: "Close", center: "Select", right: "" } : null
  );
  document.documentElement.className =
    document.documentElement.className.replace(/\s*has-layer/g, "") +
    (stack.length ? " has-layer" : "");
}

function removeLayer(layer: OpenLayer): void {
  const i = stack.indexOf(layer);
  if (i < 0) return;
  stack.splice(i, 1);
  layer.el.classList.remove("open");
  removeNode(layer.el);
  refreshSoftkeys();
  if (layer.onClose) layer.onClose();
  if (layer.returnFocus && document.body.contains(layer.returnFocus))
    focus(layer.returnFocus);
}

export function openLayer(opts: {
  kind: "sheet" | "dialog" | "drawer" | "full";
  label: string;
  body: SafeHtml;
  onClose?: () => void;
  softkeys?: Softkeys;
  focusSelector?: string;
  className?: string;
  beforeClose?: () => boolean;
}): Layer {
  const el = document.createElement("div");
  el.className = `layer layer-${opts.kind}${opts.className ? " " + opts.className : ""}`;
  el.setAttribute("role", "dialog");
  el.setAttribute("aria-modal", "true");
  el.setAttribute("aria-label", opts.label);
  setHtml(
    el,
    html`<div class="layer-backdrop" data-layer-close></div>
      <div class="layer-panel">${opts.body}</div>`
  );
  host().appendChild(el);

  const layer: OpenLayer = {
    el,
    returnFocus: document.activeElement as HTMLElement | null,
    onClose: opts.onClose,
    beforeClose: opts.beforeClose,
    softkeys: opts.softkeys,
    close: () => {
      if (stack.indexOf(layer) < 0) return;
      removeLayer(layer);
      layerHistory.changed();
    },
    requestClose: () => {
      if (layer.beforeClose && layer.beforeClose()) return;
      layer.close();
    },
  };
  stack.push(layer);
  layerHistory.changed();
  // Force a style pass so the open transition runs.
  void el.offsetHeight;
  el.classList.add("open");
  refreshSoftkeys();

  el.addEventListener("click", (e) => {
    const t = e.target as HTMLElement;
    if (t && t.hasAttribute && t.hasAttribute("data-layer-close"))
      layer.requestClose();
  });

  requestAnimationFrame(() => {
    if (!focusFirst(el, opts.focusSelector)) {
      const panel = $(".layer-panel", el);
      if (panel) {
        panel.setAttribute("tabindex", "-1");
        panel.focus();
      }
    }
  });
  return layer;
}

export function topLayer(): Layer | null {
  return stack[stack.length - 1] || null;
}

export function closeTop(): boolean {
  const top = stack[stack.length - 1];
  if (!top) return false;
  top.requestClose();
  return true;
}

// Router hook: a Back press while a layer is open closes that layer.
export function handlePop(): boolean {
  if (layerHistory.popped()) return true;
  const top = stack[stack.length - 1];
  if (!top) return false;
  // The layer stays open (it asks first): put its entry back.
  if (top.beforeClose && top.beforeClose()) layerHistory.changed();
  else removeLayer(top);
  return true;
}

// Moving to another screen: drop every layer, then navigate(replace) once
// history is where the navigation belongs. Focus first goes back to what
// opened the layers, so the screen being left remembers that item for Back.
//
// A plain move from one layer (a drawer link) reuses that layer's entry for
// the new screen. A replacing move (jump to a post) or one from stacked layers
// first goes back over the layer entries, so it replaces the screen's own
// entry and no stale layer entry is left under the new screen.
export function leaveScreen(
  replace: boolean,
  navigate: (replace: boolean) => void
): void {
  const opener = stack.length ? stack[0].returnFocus : null;
  const entries = layerHistory.reset();
  while (stack.length) {
    const top = stack[stack.length - 1];
    top.returnFocus = null;
    removeLayer(top);
  }
  if (opener && document.body.contains(opener)) focus(opener);
  if (!entries || !isLayerState()) navigate(replace);
  else if (entries === 1 && !replace) navigate(true);
  else layerHistory.popThen(entries, () => navigate(replace));
}

// A screen is (re)rendering in place: drop any layers still open, but let
// their history entries go the normal way, so a re-render right after a
// sheet closed (a preference changed) doesn't strand that sheet's entry.
export function dropLayers(): void {
  if (!stack.length) return;
  while (stack.length) {
    const top = stack[stack.length - 1];
    top.returnFocus = null;
    removeLayer(top);
  }
  layerHistory.changed();
}

// ── Ready-made dialogs ────────────────────────────────────────────────

export function alertDialog(message: string, title = ""): Promise<void> {
  return new Promise((resolve) => {
    const layer = openLayer({
      kind: "dialog",
      label: title || "Message",
      body: html`<div class="dialog">
        ${title ? html`<h2 class="dialog-title">${title}</h2>` : ""}
        <p class="dialog-text">${message}</p>
        <div class="dialog-actions" data-row>
          <button type="button" class="btn primary" data-ok>OK</button>
        </div>
      </div>`,
      softkeys: { left: "", center: "OK", right: "" },
      onClose: () => resolve(),
    });
    const ok = $("[data-ok]", layer.el);
    if (ok) ok.addEventListener("click", () => layer.close());
  });
}

export function confirmDialog(
  message: string,
  opts: { title?: string; ok?: string; cancel?: string; danger?: boolean } = {}
): Promise<boolean> {
  return new Promise((resolve) => {
    let result = false;
    const layer = openLayer({
      kind: "dialog",
      label: opts.title || "Confirm",
      body: html`<div class="dialog">
        ${opts.title ? html`<h2 class="dialog-title">${opts.title}</h2>` : ""}
        <p class="dialog-text">${message}</p>
        <div class="dialog-actions" data-row>
          <button type="button" class="btn" data-cancel>
            ${opts.cancel || "Cancel"}
          </button>
          <button
            type="button"
            class="btn ${opts.danger ? "danger" : "primary"}"
            data-ok
          >
            ${opts.ok || "OK"}
          </button>
        </div>
      </div>`,
      softkeys: {
        left: opts.cancel || "Cancel",
        center: "Select",
        right: opts.ok || "OK",
      },
      focusSelector: "[data-ok]",
      onClose: () => resolve(result),
    });
    const ok = $("[data-ok]", layer.el);
    const cancel = $("[data-cancel]", layer.el);
    if (ok)
      ok.addEventListener("click", () => {
        result = true;
        layer.close();
      });
    if (cancel) cancel.addEventListener("click", () => layer.close());
    layer.el.setAttribute("data-softright", "[data-ok]");
  });
}

export function promptDialog(
  label: string,
  opts: {
    title?: string;
    value?: string;
    placeholder?: string;
    ok?: string;
    type?: string;
    multiline?: boolean;
    hint?: string;
  } = {}
): Promise<string | null> {
  return new Promise((resolve) => {
    let result: string | null = null;
    const field = opts.multiline
      ? html`<textarea
          id="dlgInput"
          rows="4"
          placeholder="${opts.placeholder || ""}"
        >
${opts.value || ""}</textarea
        >`
      : html`<input
          id="dlgInput"
          type="${opts.type || "text"}"
          value="${opts.value || ""}"
          placeholder="${opts.placeholder || ""}"
          autocomplete="off"
        />`;
    const layer = openLayer({
      kind: "dialog",
      label: opts.title || label,
      body: html`<form class="dialog" data-form>
        ${opts.title ? html`<h2 class="dialog-title">${opts.title}</h2>` : ""}
        <label class="field-label" for="dlgInput">${label}</label>
        ${field} ${opts.hint ? html`<p class="hint">${opts.hint}</p>` : ""}
        <div class="dialog-actions" data-row>
          <button type="button" class="btn" data-cancel>Cancel</button>
          <button type="submit" class="btn primary" data-ok>
            ${opts.ok || "OK"}
          </button>
        </div>
      </form>`,
      softkeys: { left: "Cancel", center: "", right: opts.ok || "OK" },
      focusSelector: "#dlgInput",
      onClose: () => resolve(result),
    });
    const form = $("[data-form]", layer.el) as HTMLFormElement;
    const input = $("#dlgInput", layer.el) as HTMLInputElement;
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      result = input.value;
      layer.close();
    });
    const cancel = $("[data-cancel]", layer.el);
    if (cancel) cancel.addEventListener("click", () => layer.close());
    layer.el.setAttribute("data-softright", "[data-ok]");
  });
}

export interface SheetItem {
  label: HtmlValue;
  icon?: string;
  hint?: HtmlValue;
  danger?: boolean;
  active?: boolean;
  disabled?: boolean;
  run?: () => void;
  href?: string;
  external?: boolean;
  // Rendered as a heading, not an item.
  heading?: boolean;
}

// An action sheet: a titled list of choices. Picking one closes the sheet
// and runs it.
export function actionSheet(
  title: HtmlValue,
  items: SheetItem[],
  opts: { subtitle?: HtmlValue; label?: string } = {}
): Layer {
  const rows: SafeHtml[] = [];
  items.forEach((item, i) => {
    if (item.heading) {
      rows.push(html`<li class="sheet-heading">${item.label}</li>`);
      return;
    }
    const cls = `sheet-item${item.danger ? " danger" : ""}${item.active ? " active" : ""}`;
    const inner = html`${item.icon ? icon(item.icon) : ""}<span
        class="sheet-label"
        >${item.label}</span
      >${item.hint
        ? html`<span class="sheet-hint">${item.hint}</span>`
        : ""}${item.active ? icon("check", "sheet-check") : ""}`;
    if (item.href) {
      rows.push(
        html`<li>
          <a
            class="${cls}"
            href="${item.href}"
            data-i="${i}"
            ${item.external
              ? raw(' target="_blank" rel="noopener noreferrer"')
              : ""}
            >${inner}</a
          >
        </li>`
      );
    } else {
      rows.push(
        html`<li>
          <button
            type="button"
            class="${cls}"
            data-i="${i}"
            ${item.disabled ? raw(" disabled") : ""}
          >
            ${inner}
          </button>
        </li>`
      );
    }
  });
  const layer = openLayer({
    kind: "sheet",
    label: opts.label || String(title),
    body: html`<div class="sheet">
      <div class="sheet-head">
        <div class="sheet-title">${title}</div>
        ${opts.subtitle
          ? html`<div class="sheet-sub">${opts.subtitle}</div>`
          : ""}
      </div>
      <ul class="sheet-list scroll">
        ${rows}
      </ul>
    </div>`,
    softkeys: { left: "Close", center: "Select", right: "" },
    focusSelector: ".sheet-item.active",
  });
  $$("[data-i]", layer.el).forEach((el) => {
    el.addEventListener("click", (e) => {
      const item = items[parseInt(el.getAttribute("data-i") || "-1", 10)];
      if (!item || item.disabled) return;
      if (item.href) {
        if (item.external) {
          layer.close();
          return;
        }
        e.preventDefault();
        if (goTo) goTo(item.href);
        return;
      }
      e.preventDefault();
      layer.close();
      if (item.run) item.run();
    });
  });
  return layer;
}

// ── Toasts ────────────────────────────────────────────────────────────

let toastTimer: ReturnType<typeof setTimeout> | null = null;

export function toast(
  message: string,
  kind: "info" | "error" | "success" = "info"
): void {
  let el = byId("toast");
  if (!el) {
    el = document.createElement("div");
    el.id = "toast";
    el.setAttribute("role", "status");
    el.setAttribute("aria-live", "polite");
    document.body.appendChild(el);
  }
  el.className = `toast toast-${kind} show`;
  setHtml(
    el,
    html`${icon(
        kind === "error" ? "info" : kind === "success" ? "check" : "info"
      )}<span>${message}</span>`
  );
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(
    () => {
      if (el) el.className = `toast toast-${kind}`;
    },
    kind === "error" ? 5000 : 2600
  );
}
