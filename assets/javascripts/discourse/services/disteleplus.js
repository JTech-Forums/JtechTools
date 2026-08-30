import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import KeyValueStore from "discourse/lib/key-value-store";
import { emojiUrlFor } from "discourse/lib/text";

const BASE = "/jtech-disteleplus";
const CHANNEL = "/disteleplus/conversation";
const IMAGE_EXTENSIONS = new Set(["png", "jpg", "jpeg", "gif", "webp"]);
const VIDEO_EXTENSIONS = new Set(["mp4", "mov", "webm"]);
const AUDIO_EXTENSIONS = new Set(["mp3", "m4a", "ogg", "wav", "flac", "opus"]);
const DRAFT_KEY = "disteleplus-draft";
const STORE_NAMESPACE = "disteleplus_";
const PREFERRED_MODE_KEY = "preferred_mode";
const FULL_PAGE = "FULL_PAGE";
const DRAWER = "DRAWER";
const DEFAULT_SIZE = { width: 400, height: 530 };
const MIN_WIDTH = 250;
const MIN_HEIGHT = 300;

export default class DisteleplusService extends Service {
  @service currentUser;
  @service messageBus;
  @service site;
  @service router;
  @service appEvents;

  @tracked messages = [];
  @tracked loading = false;
  @tracked loadingOlder = false;
  @tracked loaded = false;
  @tracked sending = false;
  @tracked unreadCount = 0;
  @tracked hasMore = false;
  @tracked error = null;
  // Composer draft, restored across navigations (and reloads via localStorage).
  @tracked draft = "";

  // Drawer state, modelled on core Chat's ChatStateManager / ChatDrawerSize.
  @tracked isDrawerActive = false;
  @tracked isDrawerExpanded = false;
  @tracked drawerSize = DEFAULT_SIZE;
  // draws its unread divider after this id.
  @tracked openedAtReadId = null;
  store = new KeyValueStore(STORE_NAMESPACE);

  latestMessageId = null;
  lastReadMessageId = null;
  subscribed = false;
  viewing = false;
  loadPromise = null;
  // Read cursor as it stood when the conversation was opened; the timeline

  listeners = new Set();

  onRealtime = (payload) => {
    if (!payload?.message) {
      return;
    }
    const existed = this.messages.some(
      (message) => message.id === payload.message.id
    );
    const message = this.upsert(payload.message);
    this.latestMessageId = Math.max(this.latestMessageId || 0, message.id);
    if (payload.type === "created" && !existed) {
      const mine = message.user?.id === this.currentUser.id;
      if (!mine && !this.viewing) {
        this.unreadCount += 1;
      }
      // The timeline decides whether to auto-scroll (and mark read) or show
      // the "new messages" pill, so a reader scrolled up is not yanked down.
      this.listeners.forEach((callback) => callback(message, { mine }));
      if (!mine && this.viewing && this.listeners.size === 0) {
        this.markRead(message.id);
      }
    }
  };

  lastAppURL = null;

  constructor() {
    super(...arguments);
    try {
      this.draft = window.localStorage.getItem(DRAFT_KEY) || "";
    } catch {
      this.draft = "";
    }
    this.drawerSize = {
      width: Math.max(
        this.store.getObject("width") || DEFAULT_SIZE.width,
        MIN_WIDTH
      ),
      height: Math.max(
        this.store.getObject("height") || DEFAULT_SIZE.height,
        MIN_HEIGHT
      ),
    };
  }

  // ── drawer / full page ────────────────────────────────────────────────────

  get isFullPageActive() {
    return this.router.currentRouteName === "disteleplus";
  }

  storeAppURL() {
    const url = this.router.currentURL;
    if (url && !url.startsWith("/disteleplus")) {
      this.lastAppURL = url;
    }
  }

  get isActive() {
    return this.isFullPageActive || this.isDrawerActive;
  }

  // Mobile is always full page; desktop defaults to the drawer unless the
  // user chose "open in full page".
  get isFullPagePreferred() {
    return !!(
      this.site.mobileView ||
      this.store.getObject(PREFERRED_MODE_KEY) === FULL_PAGE
    );
  }

  get isDrawerPreferred() {
    return !this.isFullPagePreferred;
  }

  prefersFullPage() {
    this.store.setObject({ key: PREFERRED_MODE_KEY, value: FULL_PAGE });
  }

  prefersDrawer() {
    this.store.setObject({ key: PREFERRED_MODE_KEY, value: DRAWER });
  }

  openDrawer() {
    this.isDrawerActive = true;
    this.isDrawerExpanded = true;
    this.ensureLoaded().catch(() => {});
    this.appEvents.trigger("disteleplus:drawer-changed");
  }

  closeDrawer() {
    this.isDrawerActive = false;
    this.isDrawerExpanded = false;
    this.appEvents.trigger("disteleplus:drawer-changed");
  }

  toggleDrawerExpanded() {
    this.isDrawerActive = true;
    this.isDrawerExpanded = !this.isDrawerExpanded;
    this.appEvents.trigger("disteleplus:drawer-changed");
  }

  setDrawerSize({ width, height }) {
    const next = {
      width: Math.max(Math.round(width), MIN_WIDTH),
      height: Math.max(Math.round(height), MIN_HEIGHT),
    };
    this.drawerSize = next;
    this.store.setObject({ key: "width", value: next.width });
    this.store.setObject({ key: "height", value: next.height });
  }

  setDraft(value) {
    this.draft = value || "";
    try {
      if (this.draft) {
        window.localStorage.setItem(DRAFT_KEY, this.draft);
      } else {
        window.localStorage.removeItem(DRAFT_KEY);
      }
    } catch {
      // Storage may be unavailable; the in-memory draft still works.
    }
  }

  onNewMessage(callback) {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }

  ensureLoaded() {
    if (this.loaded) {
      return Promise.resolve(this.messages);
    }
    if (this.loadPromise) {
      return this.loadPromise;
    }

    this.loading = true;
    this.error = null;
    this.loadPromise = ajax(`${BASE}/conversation`)
      .then((response) => {
        this.messages = response.messages.map((message) =>
          this.hydrate(message)
        );
        this.unreadCount = response.meta.unread_count || 0;
        this.hasMore = response.meta.has_more;
        this.latestMessageId = response.meta.latest_message_id;
        this.lastReadMessageId = response.meta.last_read_message_id;
        this.openedAtReadId = this.lastReadMessageId;
        this.loaded = true;
        this.subscribe();
        return this.messages;
      })
      .catch((error) => {
        this.error = error;
        throw error;
      })
      .finally(() => {
        this.loading = false;
        this.loadPromise = null;
      });
    return this.loadPromise;
  }

  async loadOlder() {
    if (this.loadingOlder || !this.hasMore || !this.messages.length) {
      return [];
    }
    this.loadingOlder = true;
    try {
      const beforeId = this.messages[0].id;
      const response = await ajax(
        `${BASE}/messages?before_id=${beforeId}&limit=40`
      );
      const older = response.messages.map((message) => this.hydrate(message));
      this.messages = [...older, ...this.messages];
      this.hasMore = response.meta.has_more;
      return older;
    } finally {
      this.loadingOlder = false;
    }
  }

  async createMessage({ raw, uploadIds, replyToId }) {
    this.sending = true;
    try {
      const response = await ajax(`${BASE}/messages`, {
        type: "POST",
        data: {
          raw,
          upload_ids: uploadIds,
          reply_to_id: replyToId,
        },
      });
      this.upsert(response.message);
      this.setDraft("");
      return response.message;
    } finally {
      this.sending = false;
    }
  }

  async updateMessage(id, raw) {
    const response = await ajax(`${BASE}/messages/${id}`, {
      type: "PUT",
      data: { raw },
    });
    this.upsert(response.message);
    this.setDraft("");
    return response.message;
  }

  async deleteMessage(id) {
    const response = await ajax(`${BASE}/messages/${id}`, { type: "DELETE" });
    this.upsert(response.message);
  }

  async toggleReaction(message, emoji) {
    const current = message.reactions.find(
      (reaction) => reaction.emoji === emoji
    );
    const type = current?.reacted ? "DELETE" : "PUT";
    const response = await ajax(
      `${BASE}/messages/${message.id}/reactions/${encodeURIComponent(emoji)}`,
      { type }
    );
    this.upsert(response.message);
  }

  async markRead(id = this.latestMessageId) {
    if (!id || id <= (this.lastReadMessageId || 0)) {
      return;
    }
    this.lastReadMessageId = id;
    this.unreadCount = 0;
    await ajax(`${BASE}/read`, {
      type: "POST",
      data: { message_id: id },
    });
  }

  setViewing(value) {
    this.viewing = value;
    if (value) {
      this.openedAtReadId = this.lastReadMessageId;
      this.markRead();
    }
  }

  subscribe() {
    if (this.subscribed) {
      return;
    }
    this.messageBus.subscribe(CHANNEL, this.onRealtime);
    this.subscribed = true;
  }

  upsert(rawMessage) {
    const message = this.hydrate(rawMessage);
    const index = this.messages.findIndex(
      (candidate) => candidate.id === message.id
    );
    if (index === -1) {
      this.messages = [...this.messages, message].sort((a, b) => a.id - b.id);
    } else {
      const next = [...this.messages];
      next[index] = message;
      this.messages = next;
    }
    return message;
  }

  hydrate(message) {
    const mine = message.user?.id === this.currentUser?.id;
    const staff = this.currentUser?.admin || this.currentUser?.moderator;
    return {
      ...message,
      mine,
      can_edit:
        message.can_edit ||
        (!message.deleted && message.source === "discourse" && (mine || staff)),
      can_delete:
        message.can_delete ||
        (!message.deleted && message.source === "discourse" && (mine || staff)),
      can_react: !message.deleted,
      createdDate: new Date(message.created_at),
      uploads: (message.uploads || []).map((upload) =>
        this.hydrateUpload(upload)
      ),
      reactions: (message.reactions || []).map((reaction) => ({
        ...reaction,
        url: emojiUrlFor(reaction.emoji),
        display: `:${reaction.emoji}:`,
      })),
    };
  }

  hydrateUpload(upload) {
    const extension = (upload.extension || "").toLowerCase();
    let kind = "document";
    if (IMAGE_EXTENSIONS.has(extension)) {
      kind = "image";
    } else if (VIDEO_EXTENSIONS.has(extension)) {
      kind = "video";
    } else if (AUDIO_EXTENSIONS.has(extension)) {
      kind = "audio";
    }
    return { ...upload, kind };
  }
}
