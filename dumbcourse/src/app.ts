// The app shell: top bar, side menu, soft keys, global keys and in-app
// links. Views plug into it through screen.ts.

import { onNetworkActivity, onSessionLost } from "./api.ts";
import { closest } from "./compat.ts";
import { APP_ROOT, settings } from "./config.ts";
import { $, byId, setHtml, show, toggleClass } from "./dom.ts";
import { html, type SafeHtml } from "./html.ts";
import {
  isDeferred,
  isTypingTarget,
  keyOf,
  keySignature,
  setCustomKeys,
  type Key,
} from "./keys.ts";
import {
  activeScope,
  currentKey,
  focus,
  focusByKey,
  move,
  moveInRow,
  switchTab,
} from "./nav.ts";
import {
  applyPrefs,
  onPrefsChange,
  prefs,
  setPref,
  noteKey,
  softkeysVisible,
} from "./prefs.ts";
import * as router from "./router.ts";
import {
  beginScreen,
  runAction,
  screenKey,
  screenSoftActions,
  screenSoftkey,
  setComposeHook,
  setTitleHook,
} from "./screen.ts";
import {
  isStaff,
  loggedIn,
  onUserChange,
  refreshUser,
  unreadNotifications,
  user,
} from "./session.ts";
import { avatar } from "./site.ts";
import { icon } from "./ui/icons.ts";
import {
  closeTop,
  discardAll,
  handlePop,
  openLayer,
  setNavigator,
  toast,
  topLayer,
  type Layer,
} from "./ui/layers.ts";
import { currentSoftkeys, mountSoftkeys } from "./ui/softkeys.ts";

export function go(path: string, opts: { replace?: boolean } = {}): void {
  let p = path;
  if (p.indexOf(APP_ROOT) === 0) p = p.slice(APP_ROOT.length) || "/";
  const replace = discardAll() || !!opts.replace;
  router.navigate(p, { replace });
}

// ── Shell markup ──────────────────────────────────────────────────────

function shell(): SafeHtml {
  return html` <a class="skip" href="#app">Skip to content</a>
    <header id="topbar" role="banner" data-row>
      <button type="button" id="tbBack" class="tb-btn" aria-label="Back">
        ${icon("back")}
      </button>
      <a
        id="tbHome"
        class="tb-home"
        href="${router.href("/")}"
        aria-label="Home"
        >${settings.siteIcon
          ? html`<img
              src="${settings.siteIcon}"
              alt=""
              width="22"
              height="22"
            />`
          : icon("home")}</a
      >
      <div class="tb-title">
        <div id="tbTitle" class="tb-t"></div>
        <div id="tbSub" class="tb-s"></div>
      </div>
      <button
        type="button"
        id="tbCompose"
        class="tb-btn tb-compose"
        aria-label="New"
        hidden
      >
        ${icon("plus")}
      </button>
      <a
        id="tbSearch"
        class="tb-btn tb-search"
        href="${router.href("/search")}"
        aria-label="Search"
        >${icon("search")}</a
      >
      <a
        id="tbBell"
        class="tb-btn"
        href="${router.href("/notifications")}"
        aria-label="Notifications"
        >${icon("bell")}<span id="tbBadge" class="badge" hidden></span
      ></a>
      <button
        type="button"
        id="tbMenu"
        class="tb-btn"
        aria-label="Menu"
        aria-haspopup="true"
      >
        ${icon("menu")}<span id="tbDot" class="dot" hidden></span>
      </button>
    </header>
    <div id="loadbar" aria-hidden="true"><span></span></div>
    <main id="app" tabindex="-1"></main>
    <nav id="softkeys" aria-label="Soft keys"></nav>
    <div id="layers"></div>`;
}

let composeTarget: string | null = null;

function setTitle(text: string, back: boolean, sub: string): void {
  const t = byId("tbTitle");
  const s = byId("tbSub");
  if (t) t.textContent = text || settings.siteTitle;
  if (s) {
    s.textContent = sub;
    show(s, !!sub);
  }
  document.title =
    text && text !== settings.siteTitle
      ? `${text} · ${settings.siteTitle}`
      : settings.siteTitle;
  show(byId("tbBack"), back);
  show(byId("tbHome"), !back);
}

function setCompose(target: string | null, label: string): void {
  composeTarget = target;
  const btn = byId("tbCompose");
  if (!btn) return;
  btn.hidden = !target;
  btn.setAttribute("aria-label", label || "New");
}

function updateBadges(): void {
  const n = unreadNotifications();
  const badge = byId("tbBadge");
  if (badge) {
    badge.hidden = n <= 0;
    badge.textContent = n > 99 ? "99+" : String(n);
  }
  const bell = byId("tbBell");
  if (bell) {
    bell.setAttribute(
      "aria-label",
      n ? `Notifications, ${n} unread` : "Notifications"
    );
    show(bell, loggedIn());
  }
  show(byId("tbSearch"), loggedIn());
  show(byId("tbMenu"), true);
  const u = user;
  const extra = u
    ? u.reviewable_count +
      u.reqpm_incoming_count +
      u.new_personal_messages_notifications_count
    : 0;
  const dot = byId("tbDot");
  if (dot) dot.hidden = extra <= 0;
}

// ── Side menu ─────────────────────────────────────────────────────────

let menuLayer: Layer | null = null;

function menuItem(
  path: string,
  label: string,
  iconName: string,
  count = 0
): SafeHtml {
  const here = router.currentPath() === path;
  return html`<li>
    <a class="menu-item${here ? " here" : ""}" href="${router.href(path)}"
      >${icon(iconName)}<span class="menu-label">${label}</span>${count > 0
        ? html`<span class="badge">${count > 99 ? "99+" : count}</span>`
        : ""}</a
    >
  </li>`;
}

export function openMenu(): void {
  if (menuLayer && topLayer() === menuLayer) return;
  const u = user;
  const items: SafeHtml[] = [];
  const screenActions = screenSoftActions();
  screenActions.forEach((a, i) =>
    items.push(
      html`<li>
        <button
          type="button"
          class="menu-item"
          data-menu="screen"
          data-index="${i}"
        >
          ${icon("more")}<span class="menu-label">${a.label}</span>
        </button>
      </li>`
    )
  );
  if (screenActions.length)
    items.push(html`<li class="menu-sep" role="separator"></li>`);
  if (u) {
    items.push(menuItem("/", "Home", "home"));
    items.push(menuItem("/categories", "Categories", "grid"));
    items.push(
      menuItem("/notifications", "Notifications", "bell", unreadNotifications())
    );
    items.push(menuItem("/bookmarks", "Bookmarks", "bookmark"));
    if (
      u.can_send_private_messages ||
      u.new_personal_messages_notifications_count > 0
    ) {
      items.push(
        menuItem(
          "/messages",
          "Messages",
          "mail",
          u.new_personal_messages_notifications_count
        )
      );
    }
    if (u.reqpm_available)
      items.push(
        menuItem(
          "/contacts",
          "Contact requests",
          "phone",
          u.reqpm_incoming_count
        )
      );
    items.push(menuItem("/drafts", "Drafts", "draft"));
    items.push(menuItem("/search", "Search", "search"));
    if (isStaff() || u.can_review)
      items.push(
        menuItem("/review", "Review queue", "review", u.reviewable_count)
      );
    items.push(html`<li class="menu-sep" role="separator"></li>`);
    items.push(menuItem("/preferences", "Preferences", "gear"));
    if (u.can_pair_devices)
      items.push(menuItem("/link", "Sign in another device", "devices"));
  } else {
    items.push(menuItem("/login", "Sign in", "login"));
    if (settings.auth.signup)
      items.push(menuItem("/signup", "Create account", "user"));
    items.push(html`<li class="menu-sep" role="separator"></li>`);
    items.push(menuItem("/preferences", "Display settings", "gear"));
  }
  items.push(menuItem("/help", "Keys & shortcuts", "keypad"));
  const themeLabel =
    prefs.theme === "auto"
      ? "Theme: automatic"
      : prefs.theme === "light"
        ? "Theme: light"
        : "Theme: dark";
  items.push(
    html`<li>
      <button type="button" class="menu-item" data-menu="theme">
        ${icon(prefs.theme === "light" ? "sun" : "moon")}<span
          class="menu-label"
          >${themeLabel}</span
        >
      </button>
    </li>`
  );
  items.push(
    html`<li>
      <a class="menu-item" href="${router.href("/full-site")}" data-full-site
        >${icon("external")}<span class="menu-label">Full site</span></a
      >
    </li>`
  );
  if (u)
    items.push(
      html`<li>
        <button type="button" class="menu-item danger" data-menu="logout">
          ${icon("logout")}<span class="menu-label">Log out</span>
        </button>
      </li>`
    );

  const head = u
    ? html`<a
        class="menu-me"
        href="${router.href("/u/" + encodeURIComponent(u.username))}"
        >${avatar(u.avatar_template, 36, "avatar")}<span
          ><strong>${u.name || u.username}</strong
          ><small>@${u.username}</small></span
        ></a
      >`
    : html`<div class="menu-me"><strong>${settings.siteTitle}</strong></div>`;

  menuLayer = openLayer({
    kind: "drawer",
    label: "Menu",
    body: html`<div class="menu">
      ${head}
      <ul class="menu-list scroll">
        ${items}
      </ul>
    </div>`,
    softkeys: { left: "Close", center: "Open", right: "" },
    focusSelector: ".menu-item.here",
    onClose: () => {
      menuLayer = null;
    },
  });
  const el = menuLayer.el;
  el.addEventListener("click", (e) => {
    const btn = closest(e.target, "[data-menu]");
    if (!btn) return;
    const what = btn.getAttribute("data-menu");
    if (what === "screen") {
      const a =
        screenActions[parseInt(btn.getAttribute("data-index") || "0", 10)];
      closeTop();
      if (a) a.run();
    } else if (what === "theme") {
      const next =
        prefs.theme === "auto"
          ? "dark"
          : prefs.theme === "dark"
            ? "light"
            : "auto";
      setPref("theme", next);
      closeTop();
      toast(
        next === "auto"
          ? "Theme follows your phone"
          : next === "light"
            ? "Light theme"
            : "Dark theme"
      );
    } else if (what === "logout") {
      closeTop();
      go("/logout");
    }
  });
}

// ── Keys ──────────────────────────────────────────────────────────────

function nativelyActivates(el: HTMLElement): boolean {
  const tag = el.tagName;
  return (
    tag === "A" ||
    tag === "BUTTON" ||
    tag === "INPUT" ||
    tag === "SELECT" ||
    tag === "TEXTAREA" ||
    tag === "SUMMARY" ||
    tag === "LABEL"
  );
}

function goBackOrClose(): void {
  if (closeTop()) return;
  if (router.currentPath() === "/" || router.currentPath() === "/login") return;
  router.back();
}

function softLeft(): void {
  const layer = topLayer();
  if (layer) {
    const target = layer.el.getAttribute("data-softleft");
    const btn = target ? $(target, layer.el) : null;
    if (btn) btn.click();
    else closeTop();
    return;
  }
  if (!screenSoftkey("left")) openMenu();
}

function softRight(): void {
  const layer = topLayer();
  if (layer) {
    const target = layer.el.getAttribute("data-softright");
    const btn = target ? $(target, layer.el) : null;
    if (btn) btn.click();
    return;
  }
  screenSoftkey("right");
}

function centerKey(): void {
  const el = document.activeElement as HTMLElement | null;
  if (el && el !== document.body) el.click();
}

// Whether the last keydown was an anonymous one to finish on keyup.
let deferredDown = false;
let suggestedPhoneKeys = false;

function onKeydown(e: KeyboardEvent): void {
  const target = document.activeElement as HTMLElement | null;
  const typing = isTypingTarget(target);
  const key = keyOf(e, typing);
  deferredDown = !key && isDeferred(e);
  if (!key) {
    if (!deferredDown && !typing) suggestPhoneKeys(e);
    return;
  }
  dispatchKey(key, e, target, typing);
}

function onKeyup(e: KeyboardEvent): void {
  if (!deferredDown) return;
  deferredDown = false;
  const target = document.activeElement as HTMLElement | null;
  const typing = isTypingTarget(target);
  const key = keyOf(e, typing);
  if (!key) {
    if (!typing) suggestPhoneKeys(e);
    return;
  }
  // In a text field the keyboard owns everything but the soft keys.
  if (typing && key !== "softleft" && key !== "softright") return;
  dispatchKey(key, e, target, typing);
}

// A key Dumbcourse can tell apart but has no use for, on a phone-sized
// screen: likely a soft key under a name we don't know. Say once where to
// teach it.
const NOT_SOFT_KEYS =
  /^(Shift|Control|Alt|AltGraph|Meta|OS|CapsLock|NumLock|ScrollLock|Fn|FnLock|Tab|Home|End|PageUp|PageDown|Insert|Delete|Clear|Audio.*|Volume.*|Media.*|Power|F([3-9]|1\d))$/;

function suggestPhoneKeys(e: KeyboardEvent): void {
  if (suggestedPhoneKeys || !softkeysVisible() || topLayer()) return;
  const sig = keySignature(e);
  if (!sig || router.currentPath() === "/phone-keys") return;
  const name = e.key || "";
  if (name.length === 1 || NOT_SOFT_KEYS.test(name)) return;
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  suggestedPhoneKeys = true;
  toast("Unknown key. Set it up in Preferences › Phone keys.");
}

function dispatchKey(
  key: Key,
  e: KeyboardEvent,
  target: HTMLElement | null,
  typing: boolean
): void {
  noteKey(key, typing);
  const handled = (): void => {
    e.preventDefault();
    e.stopPropagation();
  };

  if (key === "softleft") {
    handled();
    softLeft();
    return;
  }
  if (key === "softright") {
    handled();
    softRight();
    return;
  }
  if (key === "escape") {
    if (target && closest(target, "[data-own-arrows]")) return;
    if (topLayer()) {
      handled();
      closeTop();
      return;
    }
    if (typing && target) {
      handled();
      target.blur();
    }
    return;
  }

  if (typing && target) {
    // Inside text: arrows edit the text, except Up/Down leave a one-line
    // field (and a textarea when the caret is at its start or end).
    if (key === "up" || key === "down") {
      if (target.tagName === "SELECT") return;
      if (target.tagName === "TEXTAREA") {
        const ta = target as HTMLTextAreaElement;
        const atStart = ta.selectionStart === 0 && ta.selectionEnd === 0;
        const atEnd = ta.selectionStart === ta.value.length;
        if ((key === "up" && !atStart) || (key === "down" && !atEnd)) return;
      }
      if (closest(target, "[data-own-arrows]")) return;
      handled();
      move(key);
    }
    return;
  }

  if (key === "up" || key === "down") {
    if (target && closest(target, "[data-own-arrows]")) return;
    handled();
    move(key);
    return;
  }
  if (key === "left" || key === "right") {
    if (target && closest(target, "[data-own-arrows]")) return;
    handled();
    if (moveInRow(key)) return;
    if (switchTab(key)) return;
    if (activeScope() === document.body && screenKey(key)) return;
    move(key === "left" ? "up" : "down");
    return;
  }
  if (key === "enter") {
    if (target && target !== document.body && !nativelyActivates(target)) {
      handled();
      const act =
        target.getAttribute("data-enter") || target.getAttribute("data-act");
      if (act && runAction(act, target, e)) return;
      target.click();
    }
    return;
  }
  if (key === "back") {
    handled();
    goBackOrClose();
    return;
  }
  if (key === "menu") {
    handled();
    openMenu();
    return;
  }

  // Keypad shortcuts (only on the page itself, not inside layers).
  if (activeScope() !== document.body) return;
  if (screenKey(key as Key)) {
    handled();
    return;
  }
  handled();
  globalShortcut(key);
}

function pageStep(direction: number): void {
  const h = (window.innerHeight || 400) * 0.85;
  window.scrollBy(0, direction * h);
}

function globalShortcut(key: Key): void {
  switch (key) {
    case "*":
      openMenu();
      break;
    case "#":
      if (loggedIn()) go("/search");
      break;
    case "0":
    case "?":
      go("/help");
      break;
    case "1":
      window.scrollTo(0, 0);
      focusFirstVisible();
      break;
    case "7":
      window.scrollTo(0, document.body.scrollHeight);
      focusFirstVisible(true);
      break;
    case "2":
      pageStep(-1);
      focusFirstVisible();
      break;
    case "8":
      pageStep(1);
      focusFirstVisible();
      break;
    case "4":
      goBackOrClose();
      break;
    default:
      break;
  }
}

function focusFirstVisible(last = false): void {
  requestAnimationFrame(() => {
    const app = byId("app");
    if (!app) return;
    const items = app.querySelectorAll("[data-key]");
    const top = (byId("topbar") as HTMLElement).offsetHeight;
    let pick: HTMLElement | null = null;
    for (let i = 0; i < items.length; i++) {
      const r = (items[i] as HTMLElement).getBoundingClientRect();
      if (r.bottom > top + 4 && r.top < (window.innerHeight || 400)) {
        pick = items[i] as HTMLElement;
        if (!last) break;
      }
    }
    if (pick) focus(pick, false);
  });
}

// ── Clicks and links ──────────────────────────────────────────────────

function onClick(e: MouseEvent): void {
  if (
    e.defaultPrevented ||
    e.button > 0 ||
    e.ctrlKey ||
    e.metaKey ||
    e.shiftKey
  )
    return;
  const actEl = closest(e.target, "[data-act]");
  if (actEl) {
    const name = actEl.getAttribute("data-act") || "";
    if (runAction(name, actEl, e)) {
      e.preventDefault();
      return;
    }
  }
  const a = closest(e.target, "a[href]") as HTMLAnchorElement | null;
  if (!a) return;
  if (a.hasAttribute("data-full-site")) return;
  if (a.target === "_blank" || a.hasAttribute("download")) return;
  const hrefValue = a.getAttribute("href") || "";
  if (!hrefValue || hrefValue.charAt(0) === "#") return;
  let path = hrefValue;
  const origin = location.protocol + "//" + location.host;
  if (path.indexOf(origin) === 0) path = path.slice(origin.length);
  if (path.indexOf(APP_ROOT + "/") !== 0 && path !== APP_ROOT) return;
  e.preventDefault();
  go(path);
}

// With live updates off there is no push of new counts; refresh them as
// people move around instead, at most once a minute.
let lastCounts = Date.now();
function refreshCountsIfQuiet(): void {
  if (prefs.live || !loggedIn() || Date.now() - lastCounts < 60000) return;
  lastCounts = Date.now();
  void refreshUser();
}

// ── Boot ──────────────────────────────────────────────────────────────

export function mountShell(): void {
  document.body.className = "dc";
  setHtml(document.body, shell());
  applyPrefs();
  onPrefsChange(() => {
    toggleClass(document.documentElement, "with-softkeys", softkeysVisible());
  });
  setTitleHook(setTitle);
  setComposeHook(setCompose);
  setNavigator((p) => go(p));

  const back = byId("tbBack");
  if (back) back.addEventListener("click", () => router.back());
  const menu = byId("tbMenu");
  if (menu) menu.addEventListener("click", () => openMenu());
  const compose = byId("tbCompose");
  if (compose)
    compose.addEventListener("click", () => {
      if (composeTarget)
        runAction(composeTarget, compose, document.createEvent("Event")) ||
          go(composeTarget);
    });

  mountSoftkeys({ left: softLeft, center: centerKey, right: softRight });
  setCustomKeys(prefs.keymap);
  onPrefsChange(() => setCustomKeys(prefs.keymap));
  document.addEventListener("keydown", onKeydown, true);
  document.addEventListener("keyup", onKeyup, true);
  document.addEventListener("click", onClick, false);
  window.addEventListener("resize", () => applyPrefs());
  window.addEventListener("offline", () =>
    toast("You're offline. Showing what was saved.", "error")
  );
  window.addEventListener("online", () => toast("Back online."));

  let loadTimer: ReturnType<typeof setTimeout> | null = null;
  onNetworkActivity((busy) => {
    const bar = byId("loadbar");
    if (!bar) return;
    if (loadTimer) clearTimeout(loadTimer);
    if (busy) loadTimer = setTimeout(() => bar.classList.add("on"), 150);
    else bar.classList.remove("on");
  });

  onUserChange(updateBadges);
  onSessionLost(() => {
    if (!loggedIn()) return;
    toast("You were signed out. Please sign in again.", "error");
    go("/logout?expired=1", { replace: true });
  });
  updateBadges();

  router.configure({
    guard: (ctx, isPublic) => {
      if (!isPublic && !loggedIn()) {
        const next = ctx.path + (location.search || "");
        router.navigate(
          "/login" + router.buildQuery({ next: next === "/" ? "" : next }),
          { replace: true }
        );
        return false;
      }
      return true;
    },
    render: (view, ctx) => {
      discardAll();
      refreshCountsIfQuiet();
      const screen = beginScreen();
      void screen;
      window.scrollTo(0, 0);
      const done = () => {
        if (ctx.restore) {
          const r = ctx.restore;
          requestAnimationFrame(() => {
            window.scrollTo(0, r.scroll);
            if (r.focusKey) focusByKey(r.focusKey);
          });
        }
      };
      try {
        const result = view(ctx);
        if (result && typeof (result as Promise<void>).then === "function")
          (result as Promise<void>).then(done, done);
        else done();
      } catch (err) {
        toast(
          String(
            (err as Error) && (err as Error).message
              ? (err as Error).message
              : err
          ),
          "error"
        );
      }
    },
    onPop: () => handlePop(),
    snapshot: () => ({
      scroll: window.pageYOffset || 0,
      focusKey: currentKey(),
    }),
  });

  // What the soft-key labels say should match what they do.
  void currentSoftkeys;
}
