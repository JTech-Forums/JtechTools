import { themePrefix } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

// Core's own site notices (email disabled, the admin's global notice…) can't
// be dismissed and have no plugin outlet, so: an × on each notice without
// one. Dismissal lasts 7 days, or until the notice's text changes (a new
// announcement always shows). Hiding is a style rule keyed on the notice id,
// so it survives core re-rendering and dismissed notices don't flash on load.
// If core's markup changes the buttons simply stop appearing.
const STORE = "jt-dismissed-notices";
const TTL = 7 * 24 * 60 * 60 * 1000;
// Notices that must stay in view
const KEEP = [
  "alert-read-only",
  "alert-staff-writes-only",
  "alert-site-archived",
  "safe-mode",
  "forced-anonymous",
  "theme-preview",
];

const read = () => {
  try {
    return JSON.parse(localStorage.getItem(STORE)) || {};
  } catch {
    return {};
  }
};

const write = (value) => {
  try {
    localStorage.setItem(STORE, JSON.stringify(value));
  } catch {
    // storage unavailable: dismissal lasts until the next page load
  }
};

const hash = (text) => {
  let h = 0;
  for (const ch of text) {
    h = (h * 31 + ch.charCodeAt(0)) | 0;
  }
  return String(h);
};

const fresh = (record) => record && Date.now() - record.t < TTL;

export default apiInitializer((api) => {
  const style = document.createElement("style");
  style.id = "jt-dismissed-notices";
  document.head.append(style);

  const hide = (ids) => {
    style.textContent = ids
      .map((id) => `#global-notice-${CSS.escape(id)}{display:none!important}`)
      .join("");
  };

  // Before first render: hide what was dismissed (re-checked below)
  const stored = read();
  hide(Object.keys(stored).filter((id) => fresh(stored[id])));

  const decorate = () => {
    const store = read();
    const hidden = [];
    let changed = false;

    for (const alert of document.querySelectorAll(
      ".global-notice .alert[id^='global-notice-']"
    )) {
      const id = alert.id.slice("global-notice-".length);
      if (KEEP.some((keep) => id.startsWith(keep))) {
        continue;
      }
      const h = hash(alert.querySelector(".text")?.textContent.trim() || "");

      if (fresh(store[id]) && store[id].h === h) {
        hidden.push(id);
        continue;
      }
      if (store[id]) {
        delete store[id]; // expired, or the text changed
        changed = true;
      }

      if (alert.querySelector(".close")) {
        continue; // core's own ×
      }
      const button = document.createElement("button");
      button.type = "button";
      button.className = "btn btn-transparent no-text close jt-notice-close";
      button.setAttribute("aria-label", i18n(themePrefix("jt.dismiss")));
      button.title = i18n(themePrefix("jt.dismiss"));
      button.innerHTML = iconHTML("xmark");
      button.addEventListener("click", () => {
        const next = read();
        next[id] = { h, t: Date.now() };
        write(next);
        decorate();
      });
      alert.append(button);
    }

    if (changed) {
      write(store);
    }
    hide(hidden);
  };

  api.onPageChange(() => requestAnimationFrame(decorate));
});
