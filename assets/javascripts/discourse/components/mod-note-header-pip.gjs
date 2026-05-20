import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { action } from "@ember/object";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";

// Avatar-overlay indicator of the moderator-notes shield-tab's own unread
// count. Injects a small badge directly onto the current-user avatar in
// the page header, mirroring Discourse's native reviewables badge.
//
// The component itself renders an invisible placeholder; on insert it
// finds the avatar element and appends a `.mod-note-avatar-pip` span to
// it. A `MutationObserver` on `document.body` re-attaches if Discourse
// re-renders the header. The count is held in sync via:
//   1. A classic Ember property observer on the current user.
//   2. A MessageBus subscription on `/mod-note-unread-count/{user_id}`.
//
// `pointer-events: none` on the badge lets clicks pass through to the
// avatar — the user menu opens normally and exposes the shield tab.
export default class ModNoteHeaderPip extends Component {
  @service currentUser;

  #onUserChange;
  #unsubscribe;
  #observer;
  #badge;
  #unreadCount = 0;

  get #avatarSelectors() {
    return [
      ".header-dropdown-toggle.current-user button",
      ".header-dropdown-toggle.current-user",
      ".header-dropdown-toggle__current-user button",
      ".header-dropdown-toggle__current-user",
    ];
  }

  #findAvatar() {
    for (const sel of this.#avatarSelectors) {
      const el = document.querySelector(sel);
      if (el) {
        return el;
      }
    }
    return null;
  }

  #ensureBadge() {
    const avatar = this.#findAvatar();
    if (!avatar) {
      return null;
    }

    // If the existing badge is still in the same avatar, reuse it.
    if (this.#badge && this.#badge.parentNode === avatar) {
      return this.#badge;
    }

    // Clean up any stale badge inside any avatar (e.g. after re-render).
    document
      .querySelectorAll(".mod-note-avatar-pip")
      .forEach((n) => n.remove());

    const span = document.createElement("span");
    span.className = "mod-note-avatar-pip";
    span.setAttribute("aria-hidden", "true");

    // Ensure the avatar can host an absolutely-positioned child.
    const cs = window.getComputedStyle(avatar);
    if (cs.position === "static") {
      avatar.style.position = "relative";
    }

    avatar.appendChild(span);
    this.#badge = span;
    return span;
  }

  #renderCount(n) {
    this.#unreadCount = Math.max(0, n | 0);
    const badge = this.#ensureBadge();
    if (!badge) {
      return;
    }
    if (this.#unreadCount > 0) {
      const label = this.#unreadCount > 9 ? "9+" : String(this.#unreadCount);
      badge.setAttribute("data-count", label);
      badge.classList.add("visible");
    } else {
      badge.removeAttribute("data-count");
      badge.classList.remove("visible");
    }
  }

  @action
  attach() {
    if (!this.currentUser?.staff) {
      return;
    }

    const initial = this.currentUser.mod_note_unread_count || 0;
    this.#renderCount(initial);

    this.#onUserChange = () => {
      this.#renderCount(this.currentUser?.mod_note_unread_count || 0);
    };
    if (typeof this.currentUser.addObserver === "function") {
      this.currentUser.addObserver("mod_note_unread_count", this.#onUserChange);
    }

    const messageBus = getOwner(this)?.lookup?.("service:message-bus");
    if (messageBus && typeof messageBus.subscribe === "function") {
      const channel = `/mod-note-unread-count/${this.currentUser.id}`;
      const handler = (payload) => {
        if (!payload) {
          return;
        }
        if (payload.reset) {
          this.currentUser?.set?.("mod_note_unread_count", 0);
          this.#renderCount(0);
          return;
        }
        if (typeof payload.delta === "number") {
          const next = Math.max(0, this.#unreadCount + payload.delta);
          this.currentUser?.set?.("mod_note_unread_count", next);
          this.#renderCount(next);
        }
      };
      messageBus.subscribe(channel, handler);
      this.#unsubscribe = () => {
        if (typeof messageBus.unsubscribe === "function") {
          messageBus.unsubscribe(channel, handler);
        }
      };
    }

    // Re-attach the badge if Discourse re-renders the header avatar.
    this.#observer = new MutationObserver(() => {
      const avatar = this.#findAvatar();
      if (!avatar) {
        return;
      }
      if (!this.#badge || this.#badge.parentNode !== avatar) {
        this.#renderCount(this.#unreadCount);
      }
    });
    this.#observer.observe(document.body, {
      childList: true,
      subtree: true,
    });
  }

  @action
  detach() {
    if (
      this.#onUserChange &&
      typeof this.currentUser?.removeObserver === "function"
    ) {
      this.currentUser.removeObserver(
        "mod_note_unread_count",
        this.#onUserChange
      );
    }
    this.#unsubscribe?.();
    this.#observer?.disconnect();
    this.#badge?.remove();
    this.#badge = null;
  }

  <template>
    <span
      style="display:none"
      {{didInsert this.attach}}
      {{willDestroy this.detach}}
    ></span>
  </template>
}
