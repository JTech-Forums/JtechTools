import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { getURLWithCDN } from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

// Desktop-only, Jelly-style pop-up "toast". Purely ADDITIVE — it renders a
// card when a new notification is published on the current user's
// `/notification/:id` MessageBus channel (the same channel that already
// drives the bell counter and the notifications dropdown) and does nothing
// else. Core notifications, the bell, the dropdown, and read-state are all
// untouched; turning the feature off simply stops the cards from appearing.
//
// Multiple notifications STACK one below another: the newest card sits at the
// top-right (just below the header search) and older ones are pushed down,
// each with its own auto-dismiss timer, up to MAX_TOASTS at once. A further
// notification drops the oldest (bottom) card so the newest can take its
// place. Clicking a card opens it (routes like the dropdown row); clicking
// anywhere else dismisses them all.
//
// Card layout: the acting user's avatar on the left (with a small type-icon
// badge on its corner), then a heading line "Name — Action" (e.g.
// "pat — Liked your post"), the topic title in bold, and a short preview of
// the message.
//
// Fires for every notification the user receives, including the plugin's
// own `custom` notifications — moderator whispers, flag notes, and
// queued/pending-post approvals/rejections — decoded via their `data`
// markers below. Never mounts on mobile or for users who have not opted in.
const AVATAR_SIZE = 48;
const EXCERPT_LENGTH = 120;
const STALE_MS = 10000;
const MAX_TOASTS = 3; // stack up to 3; a 4th drops the oldest (bottom) card
const CUSTOM_TYPE = 14; // Notification.types[:custom]

// notification_type (core enum, stable) → icon + action i18n key suffix.
const CORE_TYPES = {
  1: { icon: "at", action: "mentioned" },
  2: { icon: "reply", action: "replied" },
  3: { icon: "quote-right", action: "quoted" },
  4: { icon: "pencil", action: "edited" },
  5: { icon: "heart", action: "liked" },
  6: { icon: "envelope", action: "messaged" },
  7: { icon: "envelope", action: "messaged" },
  9: { icon: "reply", action: "posted" },
  11: { icon: "link", action: "linked" },
  12: { icon: "certificate", action: "badge" },
  15: { icon: "at", action: "mentioned" },
  17: { icon: "reply", action: "posted" },
  19: { icon: "heart", action: "liked" },
  20: { icon: "check", action: "post_approved" },
  25: { icon: "heart", action: "liked" },
};

// This plugin's `custom` notifications, keyed by their `data.mod_note_kind`.
const MOD_NOTE_KINDS = {
  post_deleted: { icon: "trash-can", action: "post_deleted" },
  post_approved: { icon: "check", action: "post_approved" },
  post_rejected: { icon: "xmark", action: "post_rejected" },
  user_note: { icon: "shield-halved", action: "user_note" },
  flag_note: { icon: "flag", action: "flag_note" },
  note: { icon: "shield-halved", action: "note" },
};

const FALLBACK = { icon: "bell", action: "default" };

export default class JtechPopupNotification extends Component {
  @service currentUser;
  @service siteSettings;
  @service site;
  @service messageBus;

  @tracked toasts = [];

  channel = null;
  seen = new Set();
  listening = false;

  constructor() {
    super(...arguments);
    if (
      !this.currentUser ||
      this.site.mobileView ||
      !this.siteSettings.popup_notifications_enabled
    ) {
      return;
    }
    this.mountedAt = Date.now();
    this.channel = `/notification/${this.currentUser.id}`;
    this.onDocumentClick = this.onDocumentClick.bind(this);
    this.messageBus.subscribe(this.channel, this.onMessage);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.dismissAll();
    if (this.channel) {
      this.messageBus.unsubscribe(this.channel, this.onMessage);
    }
  }

  // Read live so saving the account-page dropdown (which mirrors the value
  // onto currentUser) takes effect without a page reload.
  get prefEnabled() {
    return !!this.currentUser?.jtech_popup_notifications_enabled;
  }

  // Icon + action label for a notification. Core types come from the stable
  // enum map; our own `custom` notifications are decoded from their data
  // markers (whisper, mod-note kinds — which cover flag notes and
  // queued/pending-post approvals and rejections).
  metaFor(notification) {
    const data = notification.data || {};
    if (notification.notification_type === CUSTOM_TYPE) {
      if (data.mod_whisper) {
        return { icon: "eye", action: "whispered" };
      }
      if (data.mod_note) {
        return MOD_NOTE_KINDS[data.mod_note_kind] || MOD_NOTE_KINDS.note;
      }
      return FALLBACK;
    }
    return CORE_TYPES[notification.notification_type] || FALLBACK;
  }

  @action
  async onMessage(payload) {
    try {
      if (!this.prefEnabled) {
        return;
      }
      const notification = payload?.last_notification?.notification;
      if (!notification || notification.read) {
        return;
      }
      // Show each notification at most once (guards MessageBus replays and
      // re-adds after dismissal).
      if (this.seen.has(notification.id)) {
        return;
      }
      // Ignore MessageBus backlog replayed from before this tab mounted.
      const createdAt = Date.parse(notification.created_at);
      if (createdAt && createdAt < this.mountedAt - STALE_MS) {
        return;
      }
      this.seen.add(notification.id);
      await this.present(notification);
    } catch {
      // A malformed payload must never break the page.
    }
  }

  async present(notification) {
    const data = notification.data || {};
    const meta = this.metaFor(notification);
    const toast = {
      key: notification.id,
      name:
        data.display_username ||
        data.username ||
        data.original_username ||
        data.mentioned_by_username ||
        i18n("jtech_popup_notifications.someone"),
      action: i18n(`jtech_popup_notifications.action.${meta.action}`),
      icon: meta.icon,
      title: notification.fancy_title || data.topic_title || "",
      excerpt: data.excerpt || "",
      avatarUrl: null,
      url: this.urlFor(notification),
      timer: null,
    };

    // Enrich with the acting user's avatar + a preview of their message from
    // the source post. Best-effort: the card still shows without it (custom
    // notifications such as flag notes have no source post — they render the
    // type icon on its own instead of an avatar).
    try {
      const post = await this.fetchPost(notification, data);
      if (post) {
        if (post.avatar_template) {
          toast.avatarUrl = getURLWithCDN(
            post.avatar_template.replace("{size}", AVATAR_SIZE)
          );
        }
        if (!toast.excerpt && post.cooked) {
          toast.excerpt = this.excerptFrom(post.cooked);
        }
      }
    } catch {
      // ignore enrichment failure — show what we have
    }

    // The preference may have flipped off during the await.
    if (!this.prefEnabled) {
      return;
    }
    this.addToast(toast);
  }

  // Prepend the newest card; drop the oldest beyond the cap. Each card gets
  // its own auto-dismiss timer.
  addToast(toast) {
    const secs =
      parseInt(this.siteSettings.popup_notifications_timeout_seconds, 10) || 20;
    toast.timer = discourseLater(this, this.dismiss, toast, secs * 1000);

    const next = [toast, ...this.toasts];
    while (next.length > MAX_TOASTS) {
      const dropped = next.pop();
      cancel(dropped.timer);
      this.seen.delete(dropped.key);
    }
    this.toasts = next;

    if (!this.listening) {
      document.addEventListener("click", this.onDocumentClick, true);
      this.listening = true;
    }
  }

  fetchPost(notification, data) {
    if (data.original_post_id) {
      return ajax(`/posts/${data.original_post_id}.json`);
    }
    if (notification.topic_id && notification.post_number) {
      return ajax(
        `/posts/by_number/${notification.topic_id}/${notification.post_number}.json`
      );
    }
    return null;
  }

  excerptFrom(cooked) {
    const el = document.createElement("div");
    el.innerHTML = cooked;
    const text = (el.textContent || "").replace(/\s+/g, " ").trim();
    return text.length > EXCERPT_LENGTH
      ? `${text.slice(0, EXCERPT_LENGTH)}…`
      : text;
  }

  urlFor(notification) {
    const data = notification.data || {};
    if (notification.topic_id && notification.slug) {
      const suffix = notification.post_number
        ? `/${notification.post_number}`
        : "";
      return `/t/${notification.slug}/${notification.topic_id}${suffix}`;
    }
    if (data.url) {
      return data.url;
    }
    return `/u/${this.currentUser.username}/notifications`;
  }

  stopListening() {
    if (this.listening) {
      document.removeEventListener("click", this.onDocumentClick, true);
      this.listening = false;
    }
  }

  onDocumentClick(event) {
    // A click anywhere outside every card dismisses them all. Clicks on a
    // card are handled by `open` (this capture-phase listener only acts when
    // the target is outside).
    if (!event.target.closest(".jtech-popup-toast")) {
      this.dismissAll();
    }
  }

  @action
  open(toast) {
    const url = toast.url;
    this.dismiss(toast);
    if (url) {
      DiscourseURL.routeTo(url);
    }
  }

  @action
  dismiss(toast) {
    cancel(toast.timer);
    this.toasts = this.toasts.filter((t) => t !== toast);
    if (this.toasts.length === 0) {
      this.stopListening();
    }
  }

  dismissAll() {
    this.toasts.forEach((t) => cancel(t.timer));
    this.toasts = [];
    this.stopListening();
  }

  <template>
    {{#if this.toasts.length}}
      <div class="jtech-popup-toasts">
        {{#each this.toasts key="key" as |toast|}}
          <div
            class="jtech-popup-toast"
            role="button"
            tabindex="0"
            {{on "click" (fn this.open toast)}}
          >
            <div class="jtech-popup-toast__avatar">
              {{#if toast.avatarUrl}}
                <img src={{toast.avatarUrl}} width="44" height="44" alt="" />
                <span class="jtech-popup-toast__type-badge">
                  {{icon toast.icon}}
                </span>
              {{else}}
                <span class="jtech-popup-toast__type-icon">
                  {{icon toast.icon}}
                </span>
              {{/if}}
            </div>
            <div class="jtech-popup-toast__body">
              <div class="jtech-popup-toast__heading">
                <span class="jtech-popup-toast__name">{{toast.name}}</span>
                <span class="jtech-popup-toast__action">—
                  {{toast.action}}</span>
              </div>
              {{#if toast.title}}
                <div class="jtech-popup-toast__title">{{toast.title}}</div>
              {{/if}}
              {{#if toast.excerpt}}
                <div class="jtech-popup-toast__excerpt">{{toast.excerpt}}</div>
              {{/if}}
            </div>
          </div>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
