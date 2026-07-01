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

// Desktop-only, Jelly-style pop-up "toast". Purely ADDITIVE — it renders a
// card when a new notification is published on the current user's
// `/notification/:id` MessageBus channel (the same channel that already
// drives the bell counter and the notifications dropdown) and does nothing
// else. Core notifications, the bell, the dropdown, and read-state are all
// untouched; turning the feature off simply stops this card from appearing.
//
// Card layout (top → bottom): the acting user's name, their avatar on the
// left, the topic title in bold, then a short preview of their message.
//
// Never mounts on mobile (`site.mobileView`) or for users who have not
// opted in on their account page.
const AVATAR_SIZE = 48;
const EXCERPT_LENGTH = 120;
const STALE_MS = 10000;

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

  // Read live so saving the account-page dropdown (which mirrors the value
  willDestroy() {
    super.willDestroy(...arguments);
    this.clear();
    if (this.channel) {
      this.messageBus.unsubscribe(this.channel, this.onMessage);
    }
  }

  // onto currentUser) takes effect without a page reload.
  get prefEnabled() {
    return !!this.currentUser?.jtech_popup_notifications_enabled;
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
    const toast = {
      username:
        data.display_username ||
        data.username ||
        data.original_username ||
        data.mentioned_by_username ||
        "",
      title: notification.fancy_title || data.topic_title || data.title || "",
      excerpt: data.excerpt || "",
      avatarUrl: null,
      url: this.urlFor(notification),
    };

    // Enrich with the acting user's avatar + a preview of their message from
    // the source post. Best-effort: the card still shows without it.
    try {
      const post = await this.fetchPost(notification, data);
      if (post) {
        if (post.avatar_template) {
          toast.avatarUrl = getURLWithCDN(
            post.avatar_template.replace("{size}", AVATAR_SIZE)
          );
        }
        if (!toast.username && post.username) {
          toast.username = post.username;
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
          {{else}}
            {{icon "bell"}}
          {{/if}}
        </div>
        <div class="jtech-popup-toast__body">
          {{#if this.toast.username}}
            <div
              class="jtech-popup-toast__username"
            >{{this.toast.username}}</div>
          {{/if}}
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
