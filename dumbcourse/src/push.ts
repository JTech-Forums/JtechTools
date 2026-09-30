// Push notifications inside the native Dumbcourse wrapper app, which gives
// the page a `window.PushBridge`. In a normal browser this does nothing.

import { del, errorMessage, get, post, put } from "./api.ts";
import { settings } from "./config.ts";
import { html } from "./html.ts";
import { $$ } from "./dom.ts";
import { openLayer, toast } from "./ui/layers.ts";

interface Bridge {
  isNativeApp?: () => boolean;
  getDeviceId?: () => string;
  getTopic?: () => string;
  registerPush?: (server: string, topic: string) => void;
  unregisterPush?: () => void;
}

function bridge(): Bridge | null {
  const b = (window as unknown as { PushBridge?: Bridge }).PushBridge;
  try {
    return b && typeof b.isNativeApp === "function" && b.isNativeApp()
      ? b
      : null;
  } catch {
    return null;
  }
}

export function inNativeApp(): boolean {
  return !!bridge();
}

function deviceId(b: Bridge): string {
  try {
    return (b.getDeviceId && b.getDeviceId()) || "";
  } catch {
    return "";
  }
}

function newTopic(id: string): string {
  const rand = Math.random().toString(36).slice(2, 10);
  return (
    "dumbcourse-" +
    (id || "web").replace(/[^\w-]/g, "").slice(0, 8) +
    "-" +
    rand
  );
}

export function registerPush(): void {
  const b = bridge();
  if (!b || !settings.pushEnabled) return;
  const id = deviceId(b);
  if (!id) return;
  let topic = "";
  try {
    topic = (b.getTopic && b.getTopic()) || "";
  } catch {
    topic = "";
  }
  if (!/^[\w-]{8,80}$/.test(topic)) topic = newTopic(id);
  get<{ server: string; enabled: boolean }>(
    settings.basePath + "/push/info.json"
  )
    .then((info) => {
      if (!info || !info.enabled) return;
      return post<{ success?: boolean }>(
        settings.basePath + "/push/register.json",
        { topic, device_id: id }
      ).then((r) => {
        if (r && r.success && b.registerPush)
          b.registerPush(info.server, topic);
      });
    })
    .catch(() => undefined);
}

export function unregisterPush(): Promise<void> {
  const b = bridge();
  if (!b) return Promise.resolve();
  const id = deviceId(b);
  return del(settings.basePath + "/push/unregister.json", {
    device_id: id,
  }).then(
    () => {
      try {
        if (b.unregisterPush) b.unregisterPush();
      } catch {
        // ignore
      }
    },
    () => undefined
  );
}

const PREFS: Array<[string, string]> = [
  ["direct_replies", "Replies to you"],
  ["mentions", "@mentions"],
  ["quotes", "Quotes"],
  ["messages", "Messages"],
  ["watching", "Watched topics"],
  ["likes", "Likes"],
];

export function pushSettings(): void {
  get<Record<string, boolean>>(
    settings.basePath + "/push/preferences.json"
  ).then(
    (current) => {
      const layer = openLayer({
        kind: "sheet",
        label: "Push notifications",
        body: html`<div class="sheet">
          <div class="sheet-head">
            <div class="sheet-title">Push notifications</div>
          </div>
          <ul class="sheet-list scroll">
            ${PREFS.map(
              ([key, label]) =>
                html`<li>
                  <label class="check"
                    ><input
                      type="checkbox"
                      data-push="${key}"
                      ${current[key] !== false &&
                      (key !== "likes" || current[key] === true)
                        ? html` checked`
                        : ""}
                    />${label}</label
                  >
                </li>`
            )}
            <li class="pad">
              <button type="button" class="btn primary block" data-save>
                Save
              </button>
            </li>
          </ul>
        </div>`,
        softkeys: { left: "Close", center: "Toggle", right: "Save" },
      });
      layer.el.setAttribute("data-softright", "[data-save]");
      const save = layer.el.querySelector("[data-save]") as HTMLElement;
      save.addEventListener("click", () => {
        const body: Record<string, boolean> = {};
        $$<HTMLInputElement>("[data-push]", layer.el).forEach((c) => {
          body[c.getAttribute("data-push") || ""] = c.checked;
        });
        put(settings.basePath + "/push/preferences.json", body).then(
          () => {
            layer.close();
            toast("Saved.", "success");
          },
          (e: unknown) => toast(errorMessage(e), "error")
        );
      });
    },
    () => toast("Couldn't load push settings.", "error")
  );
}
