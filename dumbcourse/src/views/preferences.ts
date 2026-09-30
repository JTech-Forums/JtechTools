// Preferences: how Dumbcourse looks on this phone, the account's profile
// and email settings, and device options.

import { del, errorMessage, get, post, put } from "../api.ts";
import { go } from "../app.ts";
import { settings } from "../config.ts";
import { $, byId } from "../dom.ts";
import { html, type SafeHtml } from "../html.ts";
import { focusContent } from "../nav.ts";
import { prefs, setPref, TEXT_SIZES, type Prefs } from "../prefs.ts";
import { href, type RouteContext } from "../router.ts";
import { user } from "../session.ts";
import { icon } from "../ui/icons.ts";
import {
  actionSheet,
  confirmDialog,
  toast,
  type SheetItem,
} from "../ui/layers.ts";
import { useScreen } from "./common.ts";
import { VIEWS } from "./topics.ts";

const PREFER_COOKIE = "dumbcourse_prefer";

export function prefersDumbcourse(): boolean {
  return document.cookie.indexOf(PREFER_COOKIE + "=1") >= 0;
}

export function setPreferDumbcourse(on: boolean): void {
  const secure = location.protocol === "https:" ? "; secure" : "";
  const path = (settings.subfolder || "") + "/";
  document.cookie = on
    ? `${PREFER_COOKIE}=1; path=${path}; max-age=${3600 * 24 * 365 * 2}; samesite=lax${secure}`
    : `${PREFER_COOKIE}=0; path=${path}; max-age=${3600 * 24 * 365 * 2}; samesite=lax${secure}`;
}

function valueRow(
  key: string,
  label: string,
  value: string,
  iconName: string
): SafeHtml {
  return html`<li>
    <button
      type="button"
      class="row setting"
      data-act="pref"
      data-pref="${key}"
      data-key="pref-${key}"
    >
      <span class="row-icon">${icon(iconName)}</span>
      <div class="row-main"><div class="row-title">${label}</div></div>
      <span class="row-side">${value}</span>
    </button>
  </li>`;
}

function toggleRow(
  key: string,
  label: string,
  on: boolean,
  iconName: string
): SafeHtml {
  return html`<li>
    <button
      type="button"
      class="row setting"
      data-act="pref"
      data-pref="${key}"
      data-key="pref-${key}"
      role="switch"
      aria-checked="${on ? "true" : "false"}"
    >
      <span class="row-icon">${icon(iconName)}</span>
      <div class="row-main">
        <div class="row-title">${label}</div>
      </div>
      <span class="switch${on ? " on" : ""}" aria-hidden="true"
        ><span></span
      ></span>
    </button>
  </li>`;
}

function linkRow(path: string, label: string, iconName: string): SafeHtml {
  return html`<li>
    <a class="row setting" href="${href(path)}" data-key="link-${path}">
      <span class="row-icon">${icon(iconName)}</span>
      <div class="row-main">
        <div class="row-title">${label}</div>
      </div>
      <span class="chev">${icon("back", "flip")}</span></a
    >
  </li>`;
}

const THEMES: Array<[Prefs["theme"], string]> = [
  ["auto", "Automatic"],
  ["light", "Light"],
  ["dark", "Dark"],
];
const IMAGES: Array<[Prefs["images"], string]> = [
  ["show", "Show"],
  ["tap", "Tap to load"],
  ["hide", "Hide"],
];
const SOFTKEYS: Array<[Prefs["softkeys"], string]> = [
  ["auto", "Small screens"],
  ["on", "Always"],
  ["off", "Never"],
];

function labelOf<T>(list: Array<[T, string]>, v: T): string {
  for (let i = 0; i < list.length; i++) if (list[i][0] === v) return list[i][1];
  return "";
}

export function preferencesRoute(ctx: RouteContext): void {
  const s = useScreen();
  s.title("Preferences", { back: true });
  const u = user;
  const startLabel = prefs.defaultView
    ? (
        VIEWS.filter((v) => v.key === prefs.defaultView)[0] || {
          label: prefs.defaultView,
        }
      ).label
    : "Forum default";

  s.render(
    html` <h2 class="section-title">Display</h2>
      <ul class="rows">
        ${valueRow(
          "theme",
          "Theme",
          labelOf(THEMES, prefs.theme),
          prefs.theme === "light" ? "sun" : "moon"
        )}
        ${valueRow("textSize", "Text size", prefs.textSize + "%", "format")}
        ${toggleRow(
          "compact",
          "Compact layout",
          prefs.density === "compact",
          "list"
        )}
        ${toggleRow("avatars", "Profile pictures", prefs.avatars, "user")}
        ${valueRow(
          "images",
          "Images in posts",
          labelOf(IMAGES, prefs.images),
          "image"
        )}
        ${toggleRow(
          "excerpts",
          "Topic previews in lists",
          prefs.excerpts,
          "draft"
        )}
        ${valueRow(
          "softkeys",
          "Soft-key bar",
          labelOf(SOFTKEYS, prefs.softkeys),
          "keypad"
        )}
        ${linkRow("/phone-keys", "Phone keys", "keypad")}
      </ul>
      <h2 class="section-title">Behaviour</h2>
      <ul class="rows">
        ${valueRow("defaultView", "Start screen", startLabel, "home")}
        ${toggleRow("live", "Live updates", prefs.live, "refresh")}
        ${toggleRow(
          "prefer",
          "Open forum links here",
          prefersDumbcourse(),
          "phone"
        )}
      </ul>
      ${u
        ? html`<h2 class="section-title">Account</h2>
            <ul class="rows">
              ${linkRow("/preferences/profile", "Profile", "user")}
              ${linkRow("/preferences/email", "Email notifications", "mail")}
              ${u.can_pair_devices
                ? linkRow("/link", "Sign in another device", "devices")
                : ""}
              <li>
                <button
                  type="button"
                  class="row setting"
                  data-act="pref"
                  data-pref="password"
                  data-key="pref-password"
                >
                  <span class="row-icon">${icon("key")}</span>
                  <div class="row-main">
                    <div class="row-title">Change password</div>
                  </div>
                </button>
              </li>
              <li>
                <button
                  type="button"
                  class="row setting danger"
                  data-act="pref"
                  data-pref="logout"
                  data-key="pref-logout"
                >
                  <span class="row-icon">${icon("logout")}</span>
                  <div class="row-main">
                    <div class="row-title">Log out</div>
                  </div>
                </button>
              </li>
            </ul>`
        : ""}
      <p class="hint pad">
        Dumbcourse ${settings.version} ·
        <a href="${href("/help")}">Keys &amp; shortcuts</a> ·
        <a href="${href("/full-site")}" data-full-site>Full site</a>
      </p>`
  );

  const pick = <T extends string>(
    title: string,
    list: Array<[T, string]>,
    current: T,
    apply: (v: T) => void
  ) => {
    const items: SheetItem[] = list.map(([v, label]) => ({
      label,
      active: v === current,
      run: () => apply(v),
    }));
    actionSheet(title, items);
  };
  const again = () => go(ctx.path, { replace: true });

  s.act("pref", (el) => {
    const key = el.getAttribute("data-pref");
    switch (key) {
      case "theme":
        pick("Theme", THEMES, prefs.theme, (v) => {
          setPref("theme", v);
          again();
        });
        break;
      case "textSize":
        pick(
          "Text size",
          TEXT_SIZES.map(
            (n) =>
              [String(n), n + "%" + (n === 100 ? " (normal)" : "")] as [
                string,
                string,
              ]
          ),
          String(prefs.textSize),
          (v) => {
            setPref("textSize", parseInt(v, 10));
            again();
          }
        );
        break;
      case "compact":
        setPref(
          "density",
          prefs.density === "compact" ? "comfortable" : "compact"
        );
        again();
        break;
      case "avatars":
        setPref("avatars", !prefs.avatars);
        again();
        break;
      case "images":
        pick("Images in posts", IMAGES, prefs.images, (v) => {
          setPref("images", v);
          again();
        });
        break;
      case "excerpts":
        setPref("excerpts", !prefs.excerpts);
        again();
        break;
      case "softkeys":
        pick("Soft-key bar", SOFTKEYS, prefs.softkeys, (v) => {
          setPref("softkeys", v);
          again();
        });
        break;
      case "defaultView":
        pick(
          "Start screen",
          ([["", "Forum default"]] as Array<[string, string]>).concat(
            VIEWS.map((v) => [v.key, v.label] as [string, string])
          ),
          prefs.defaultView,
          (v) => {
            setPref("defaultView", v);
            again();
          }
        );
        break;
      case "live":
        setPref("live", !prefs.live);
        toast(
          prefs.live
            ? "Live updates on."
            : "Live updates off. Use Refresh to update."
        );
        again();
        break;
      case "prefer":
        setPreferDumbcourse(!prefersDumbcourse());
        toast(
          prefersDumbcourse()
            ? "Forum links will open in Dumbcourse on this phone."
            : "Forum links will open the full site."
        );
        again();
        break;
      case "password":
        if (!u) return;
        confirmDialog("We'll email you a link to set a new password.", {
          ok: "Send link",
        }).then((ok) => {
          if (!ok) return;
          post("/session/forgot_password.json", { login: u.username }).then(
            () => toast("Check your email for the link.", "success"),
            (e: unknown) => toast(errorMessage(e), "error")
          );
        });
        break;
      case "logout":
        go("/logout");
        break;
    }
  });
  if (!ctx.restore) focusContent(".row");
}

// ── Profile editing ───────────────────────────────────────────────────

export function profilePrefsRoute(ctx: RouteContext): Promise<void> {
  const s = useScreen();
  s.title("Profile", { back: true });
  const u = user;
  if (!u) return Promise.resolve();
  s.loading();
  return get<{
    user: {
      name?: string;
      bio_raw?: string;
      location?: string;
      website?: string;
      title?: string;
      status?: { emoji?: string; description?: string };
    };
  }>(`/u/${encodeURIComponent(u.username)}.json`).then(
    (d) => {
      if (!s.alive()) return;
      const me = d.user || {};
      const status = me.status
        ? (me.status.emoji ? ":" + me.status.emoji + ": " : "") +
          (me.status.description || "")
        : "";
      s.render(
        html`<form class="card form" data-profile>
          <div class="field">
            <label class="field-label" for="pName">Name</label
            ><input
              id="pName"
              type="text"
              value="${me.name || ""}"
              maxlength="255"
              autocomplete="name"
            />
          </div>
          <div class="field">
            <label class="field-label" for="pStatus">Status</label
            ><input
              id="pStatus"
              type="text"
              value="${status}"
              maxlength="100"
              placeholder=":palm_tree: On vacation"
            />
          </div>
          <div class="field">
            <label class="field-label" for="pBio">About me</label
            ><textarea id="pBio" rows="5">${me.bio_raw || ""}</textarea>
          </div>
          <div class="field">
            <label class="field-label" for="pLocation">Location</label
            ><input
              id="pLocation"
              type="text"
              value="${me.location || ""}"
              maxlength="100"
            />
          </div>
          <div class="field">
            <label class="field-label" for="pWebsite">Website</label
            ><input
              id="pWebsite"
              type="url"
              value="${me.website || ""}"
              placeholder="https://"
            />
          </div>
          <div class="btn-row" data-row>
            <button type="submit" class="btn primary" data-save>
              ${icon("check")}Save</button
            ><a
              class="btn"
              href="${href("/u/" + encodeURIComponent(u.username))}"
              >Cancel</a
            >
          </div>
        </form>`
      );
      const form = $("[data-profile]") as HTMLFormElement;
      s.softkeys({
        right: { label: "Save", run: () => form.dispatchEvent(makeSubmit()) },
      });
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        const val = (id: string) =>
          ((byId(id) as HTMLInputElement).value || "").replace(
            /^\s+|\s+$/g,
            ""
          );
        const body = {
          name: val("pName"),
          bio_raw: (byId("pBio") as HTMLTextAreaElement).value,
          location: val("pLocation"),
          website: val("pWebsite"),
        };
        const statusText = val("pStatus");
        const m = /^:([\w+-]+):\s*(.*)$/.exec(statusText);
        const unchanged = statusText === status;
        const statusReq: Promise<unknown> = unchanged
          ? Promise.resolve()
          : statusText
            ? put("/user-status.json", {
                emoji: m ? m[1] : "speech_balloon",
                description: m ? m[2] || m[1] : statusText,
              })
            : del("/user-status.json");
        Promise.all([
          put(`/u/${encodeURIComponent(u.username)}.json`, body),
          statusReq,
        ]).then(
          () => {
            toast("Profile saved.", "success");
            go("/u/" + encodeURIComponent(u.username), { replace: true });
          },
          (err: unknown) => toast(errorMessage(err), "error")
        );
      });
      if (!ctx.restore) focusContent("#pName");
    },
    (e: unknown) => s.error(errorMessage(e))
  );
}

function makeSubmit(): Event {
  const ev = document.createEvent("Event");
  ev.initEvent("submit", true, true);
  return ev;
}

// ── Email notifications ───────────────────────────────────────────────

const EMAIL_LEVELS: Array<[string, string]> = [
  ["0", "Always"],
  ["1", "Only when I'm away"],
  ["2", "Never"],
];

export function emailPrefsRoute(ctx: RouteContext): Promise<void> {
  const s = useScreen();
  s.title("Email notifications", { back: true });
  const u = user;
  if (!u) return Promise.resolve();
  s.loading();
  return get<{
    user: {
      user_option?: {
        email_level?: number;
        email_messages_level?: number;
        email_digests?: boolean;
      };
    };
  }>(`/u/${encodeURIComponent(u.username)}.json`).then(
    (d) => {
      if (!s.alive()) return;
      const o = (d.user && d.user.user_option) || {};
      const lvl = (n: number | undefined) =>
        labelOf(EMAIL_LEVELS, String(n === undefined ? 1 : n));
      s.render(
        html`<ul class="rows">
          ${valueRow(
            "email_level",
            "Replies & mentions",
            lvl(o.email_level),
            "reply"
          )}
          ${valueRow(
            "email_messages_level",
            "Messages",
            lvl(o.email_messages_level),
            "mail"
          )}
          ${toggleRow(
            "email_digests",
            "Summary emails",
            !!o.email_digests,
            "draft"
          )}
        </ul>`
      );
      const save = (body: Record<string, unknown>) =>
        put(`/u/${encodeURIComponent(u.username)}.json`, body).then(
          () => {
            toast("Saved.", "success");
            go(ctx.path, { replace: true });
          },
          (e: unknown) => toast(errorMessage(e), "error")
        );
      s.act("pref", (el) => {
        const key = el.getAttribute("data-pref") || "";
        if (key === "email_digests") {
          void save({ email_digests: !o.email_digests });
          return;
        }
        const current = String(
          (o as Record<string, unknown>)[key] === undefined
            ? 1
            : (o as Record<string, unknown>)[key]
        );
        actionSheet(
          key === "email_level"
            ? "Email me about replies & mentions"
            : "Email me about messages",
          EMAIL_LEVELS.map(([v, label]) => ({
            label,
            active: v === current,
            run: () => void save({ [key]: parseInt(v, 10) }),
          }))
        );
      });
      if (!ctx.restore) focusContent(".row");
    },
    (e: unknown) => s.error(errorMessage(e))
  );
}
