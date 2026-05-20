import { withPluginApi } from "discourse/lib/plugin-api";
import {
  applyUnreadPrefix,
  stripUnreadPrefix,
} from "../lib/mod-note-unread-title";

// Header-level indicators of unread moderator notes.
//
// Two staff-only signals tied to `currentUser.mod_note_unread_count`:
//   1. A header shield pip + count next to the avatar (rendered by the
//      `before-header-panel` plugin-outlet connector — its own tracked
//      local handles reactivity).
//   2. A `(N)` prefix on the browser tab title.
//
// This initializer owns the title-prefix side-effect. It tracks the
// authoritative `currentUser.mod_note_unread_count` (a property observer
// catches the panel zero-ing it; a MessageBus subscription on
// `/mod-note-unread-count/{user_id}` catches live server bumps + the
// `reset` published from `notes_feed_seen`) and re-applies the prefix
// whenever the document title changes (Discourse's `document-title`
// service rewrites the title on every route transition).
export default {
  name: "discourse-mod-note-header-indicators",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.staff) {
      return;
    }

    const messageBus = container.lookup("service:message-bus");

    let lastCount = currentUser.mod_note_unread_count || 0;

    const titleEl = document.querySelector("head > title");

    // Reapply the prefix to the current `document.title` based on `lastCount`.
    // Guarded so the MutationObserver below doesn't recurse: if the title
    // is already in its desired state we don't touch it.
    let applying = false;
    const reapply = () => {
      if (applying) {
        return;
      }
      const current = document.title;
      const next = applyUnreadPrefix(stripUnreadPrefix(current), lastCount);
      if (next !== current) {
        applying = true;
        try {
          document.title = next;
        } finally {
          applying = false;
        }
      }
    };

    // Whenever something (Discourse's document-title service, a route
    // transition, etc.) rewrites the <title> node, reassert the prefix.
    if (titleEl && typeof MutationObserver !== "undefined") {
      const observer = new MutationObserver(reapply);
      observer.observe(titleEl, { childList: true, characterData: true, subtree: true });
    }

    const recompute = () => {
      lastCount = currentUser.mod_note_unread_count || 0;
      reapply();
    };

    // Apply once at boot so an initial unread count prefixes the title
    // without waiting for the next route transition.
    recompute();

    // Reactive bridge: a property observer on the User model picks up
    // every mutation — the panel's `set("mod_note_unread_count", 0)`
    // after `notes-feed/seen`, the header pip's MessageBus handler, etc.
    if (typeof currentUser.addObserver === "function") {
      currentUser.addObserver("mod_note_unread_count", recompute);
    }

    // Independent MessageBus subscription so the title prefix updates
    // even if the pip isn't currently mounted (e.g. count was 0 at boot).
    if (messageBus && typeof messageBus.subscribe === "function") {
      messageBus.subscribe(
        `/mod-note-unread-count/${currentUser.id}`,
        (payload) => {
          if (!payload) {
            return;
          }
          if (payload.reset) {
            currentUser.set?.("mod_note_unread_count", 0);
            recompute();
            return;
          }
          if (typeof payload.delta === "number") {
            const next =
              (currentUser.mod_note_unread_count || 0) + payload.delta;
            currentUser.set?.("mod_note_unread_count", Math.max(0, next));
            recompute();
          }
        }
      );
    }

    withPluginApi("1.0", () => {
      // Reserved for future hooks (e.g. additional reactive bindings on the
      // header service when its API stabilizes). The initializer itself
      // doesn't need a plugin-api capture today.
    });
  },
};
