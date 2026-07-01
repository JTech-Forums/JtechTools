import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
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
// untouched; turning the feature off simply stops this card from appearing.
//
// Card layout: the acting user's avatar on the left (with a small type-icon
// badge on its corner), then a heading line "Name — Action" (e.g.
// "pat — Liked your post"), the topic title in bold, and a short preview of
// the message.
//
// Fires for every notification the user receives, including the plugin's
// own `custom` notifications — moderator whispers, flag notes, and
// queued/pending-post approvals/rejections — which are decoded via their
// `data` markers below.
//
// Never mounts on mobile (`site.mobileView`) or for users who have not
// opted in on their account page.
const AVATAR_SIZE = 48;
const EXCERPT_LENGTH = 120;
const STALE_MS = 10000;
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

  @tracked toast = null;

  channel = null;
  dismissHandle = null;
  lastShownId = null;

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
    this.clear();
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
      if (notification.id === this.lastShownId) {
        return;
      }
      // Ignore MessageBus backlog replayed from before this tab mounted.
      const createdAt = Date.parse(notification.created_at);
      if (createdAt && createdAt < this.mountedAt - STALE_MS) {
        return;
      }
      this.lastShownId = notification.id;
      await this.present(notification);
    } catch {
      // A malformed payload must never break the page.
    }
  }

  async present(notification) {
    const data = notification.data || {};
    const meta = this.metaFor(notification);
    const name =
      data.display_username ||
      data.username ||
      data.original_username ||
      data.mentioned_by_username ||
      i18n("jtech_popup_notifications.someone");

    const toast = {
      name,
      action: i18n(`jtech_popup_notifications.action.${meta.action}`),
      icon: meta.icon,
      title: notification.fancy_title || data.topic_title || "",
      excerpt: data.excerpt || "",
      avatarUrl: null,
      url: this.urlFor(notification),
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
    this.toast = toast;
    this.arm();
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

  arm() {
    this.clear();
    const secs =
      parseInt(this.siteSettings.popup_notifications_timeout_seconds, 10) || 20;
    this.dismissHandle = discourseLater(this, this.dismiss, secs * 1000);
    document.addEventListener("click", this.onDocumentClick, true);
  }

  clear() {
    if (this.dismissHandle) {
      cancel(this.dismissHandle);
      this.dismissHandle = null;
    }
    if (this.onDocumentClick) {
      document.removeEventListener("click", this.onDocumentClick, true);
    }
  }

  onDocumentClick(event) {
    // Clicking anywhere outside the card dismisses it. A click on the card
    // itself is handled by `open` (this listener is capture-phase and only
    // dismisses when the target is outside).
    if (!event.target.closest(".jtech-popup-toast")) {
      this.dismiss();
    }
  }

  @action
  open() {
    const url = this.toast?.url;
    this.dismiss();
    if (url) {
      DiscourseURL.routeTo(url);
    }
  }

  @action
  dismiss() {
    this.clear();
    this.toast = null;
  }

  <template>
    {{#if this.toast}}
      <div
        class="jtech-popup-toast"
        role="button"
        tabindex="0"
        {{on "click" this.open}}
      >
        <div class="jtech-popup-toast__avatar">
          {{#if this.toast.avatarUrl}}
            <img src={{this.toast.avatarUrl}} width="44" height="44" alt="" />
            <span class="jtech-popup-toast__type-badge">
              {{icon this.toast.icon}}
            </span>
          {{else}}
            <span class="jtech-popup-toast__type-icon">
              {{icon this.toast.icon}}
            </span>
          {{/if}}
        </div>
        <div class="jtech-popup-toast__body">
          <div class="jtech-popup-toast__heading">
            <span class="jtech-popup-toast__name">{{this.toast.name}}</span>
            <span class="jtech-popup-toast__action">—
              {{this.toast.action}}</span>
          </div>
          {{#if this.toast.title}}
            <div class="jtech-popup-toast__title">{{this.toast.title}}</div>
          {{/if}}
          {{#if this.toast.excerpt}}
            <div class="jtech-popup-toast__excerpt">{{this.toast.excerpt}}</div>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
