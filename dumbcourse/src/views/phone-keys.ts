// Phone keys: teach Dumbcourse this phone's soft keys, and see what each
// key press sends. Browsers name soft keys differently (or not at all),
// and some keep them for themselves; any key that reaches the page can be
// taught here. Taught keys stay on this device.

import { byId, setHtml } from "../dom.ts";
import { html } from "../html.ts";
import {
  describeSignature,
  isDeferred,
  keyOf,
  keySignature,
  type Key,
} from "../keys.ts";
import { focusContent } from "../nav.ts";
import { prefs, setPref } from "../prefs.ts";
import type { RouteContext } from "../router.ts";
import { icon } from "../ui/icons.ts";
import { toast } from "../ui/layers.ts";
import { useScreen } from "./common.ts";

type Teachable = "softleft" | "softright";

const TEACHABLE: Array<[Teachable, string]> = [
  ["softleft", "Left soft key"],
  ["softright", "Right soft key"],
];

const LABELS: Partial<Record<Key, string>> = {
  up: "Up",
  down: "Down",
  left: "Left",
  right: "Right",
  enter: "OK",
  back: "Back",
  escape: "Close",
  softleft: "Left soft key",
  softright: "Right soft key",
  menu: "Menu",
};

// Keys that already move around; teaching them would lose that.
const RESERVED: Key[] = ["up", "down", "left", "right", "enter", "back"];

function taughtSignature(which: Teachable): string | null {
  for (const sig in prefs.keymap)
    if (prefs.keymap.hasOwnProperty(sig) && prefs.keymap[sig] === which)
      return sig;
  return null;
}

function sideText(which: Teachable, listening: Teachable | null): string {
  if (listening === which) return "Press it now…";
  const sig = taughtSignature(which);
  return sig ? describeSignature(sig) : "Built in";
}

export function phoneKeysRoute(ctx: RouteContext): void {
  const s = useScreen();
  s.title("Phone keys", { back: true });

  let listening: Teachable | null = null;
  let waitingForKeyup = false;
  let downWasDeferred = false;
  let timer: ReturnType<typeof setTimeout> | null = null;

  const paintRows = () => {
    for (let i = 0; i < TEACHABLE.length; i++) {
      const side = byId("pk-" + TEACHABLE[i][0]);
      if (side) side.textContent = sideText(TEACHABLE[i][0], listening);
    }
    const reset = byId("pkReset");
    if (reset) {
      let any = false;
      for (const sig in prefs.keymap)
        if (prefs.keymap.hasOwnProperty(sig)) any = true;
      reset.hidden = !any;
    }
  };

  const paintLast = (e: KeyboardEvent) => {
    const el = byId("pkLast");
    if (!el) return;
    const sig = keySignature(e);
    const key = keyOf(e);
    const does = key ? LABELS[key] || key : sig ? "Nothing" : "Unnamed key";
    setHtml(
      el,
      html`<kbd>${sig ? describeSignature(sig) : "?"}</kbd
        ><span class="row-main"
          ><span class="row-title">${does}</span
          ><span class="hint"
            >key ${e.key || "—"} · code ${e.code || "—"} · keyCode
            ${e.keyCode || e.which || 0}</span
          ></span
        >`
    );
  };

  const stop = () => {
    listening = null;
    waitingForKeyup = false;
    if (timer) clearTimeout(timer);
    timer = null;
    paintRows();
  };

  const teach = (sig: string | null, e: KeyboardEvent) => {
    const which = listening;
    stop();
    if (!which) return;
    if (!sig) {
      toast("Your phone doesn't name that key, so it can't be used.", "error");
      return;
    }
    const current = keyOf(e);
    if (current && RESERVED.indexOf(current) >= 0 && !prefs.keymap[sig]) {
      toast(`That key is already ${LABELS[current]}.`, "error");
      return;
    }
    const map: Record<string, Key> = {};
    for (const k in prefs.keymap)
      if (prefs.keymap.hasOwnProperty(k) && prefs.keymap[k] !== which)
        map[k] = prefs.keymap[k];
    map[sig] = which;
    setPref("keymap", map);
    paintRows();
    toast(
      `${which === "softleft" ? "Left" : "Right"} soft key set.`,
      "success"
    );
  };

  // Window capture runs before the app's own key handling, so while
  // listening the press is taken here and does nothing else.
  const onDown = (e: KeyboardEvent) => {
    if (listening) {
      e.preventDefault();
      e.stopPropagation();
      if (isDeferred(e)) {
        waitingForKeyup = true;
        return;
      }
      teach(keySignature(e), e);
      paintLast(e);
      return;
    }
    downWasDeferred = isDeferred(e);
    paintLast(e);
  };
  const onUp = (e: KeyboardEvent) => {
    if (listening && waitingForKeyup) {
      e.preventDefault();
      e.stopPropagation();
      teach(keySignature(e), e);
      paintLast(e);
      return;
    }
    if (listening) e.stopPropagation();
    else if (downWasDeferred) paintLast(e);
    downWasDeferred = false;
  };
  window.addEventListener("keydown", onDown, true);
  window.addEventListener("keyup", onUp, true);
  s.onLeave(() => {
    if (timer) clearTimeout(timer);
    window.removeEventListener("keydown", onDown, true);
    window.removeEventListener("keyup", onUp, true);
  });

  s.render(
    html`<ul class="rows">
        ${TEACHABLE.map(
          ([which, label]) =>
            html`<li>
              <button
                type="button"
                class="row setting"
                data-act="pk-teach"
                data-which="${which}"
                data-key="pk-${which}"
              >
                <span class="row-icon">${icon("keypad")}</span>
                <div class="row-main">
                  <div class="row-title">${label}</div>
                </div>
                <span class="row-side" id="pk-${which}"
                  >${sideText(which, null)}</span
                >
              </button>
            </li>`
        )}
        <li id="pkReset">
          <button
            type="button"
            class="row setting danger"
            data-act="pk-reset"
            data-key="pk-reset"
          >
            <span class="row-icon">${icon("undo")}</span>
            <div class="row-main"><div class="row-title">Reset</div></div>
          </button>
        </li>
      </ul>
      <h2 class="section-title">Last key pressed</h2>
      <div class="row keys" id="pkLast" aria-live="polite">
        <kbd>—</kbd><span class="row-main"></span>
      </div>`
  );
  paintRows();

  s.act("pk-teach", (el) => {
    const which = el.getAttribute("data-which") as Teachable;
    listening = which;
    waitingForKeyup = false;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      if (!listening) return;
      stop();
      toast(
        "Nothing reached Dumbcourse. Your phone keeps that key; use * or the Menu instead.",
        "error"
      );
    }, 10000);
    paintRows();
  });
  s.act("pk-reset", () => {
    stop();
    setPref("keymap", {});
    paintRows();
    toast("Phone keys reset.");
    focusContent(".row");
  });

  if (!ctx.restore) focusContent(".row");
}
