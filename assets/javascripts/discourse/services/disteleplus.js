import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import KeyValueStore from "discourse/lib/key-value-store";
import { emojiUrlFor } from "discourse/lib/text";

const BASE = "/jtech-disteleplus";
const CHANNEL = "/disteleplus/conversation";
const TYPING_CHANNEL = "/disteleplus/typing";
const TYPING_TTL = 5000;
const TYPING_THROTTLE = 3000;
const IMAGE_EXTENSIONS = new Set(["png", "jpg", "jpeg", "gif", "webp"]);
const VIDEO_EXTENSIONS = new Set(["mp4", "mov", "webm"]);
const AUDIO_EXTENSIONS = new Set([
  "mp3",
  "m4a",
  "ogg",
  "oga",
  "wav",
  "flac",
  "opus",
  "aac",
]);
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
  // Search UI open (drawer + full page share it) and results.
  @tracked searchOpen = false;
  @tracked searchTerm = "";
  @tracked searchResults = null;
  @tracked searching = false;
  // than the live tail.
  @tracked detached = false;
  // [{ user_id, username, name, until }]
  @tracked typers = [];
  // user_id → { username, name, avatar_template, last_read_message_id }.
  // Powers the "Seen by" chip; replaced wholesale so getters recompute.
  @tracked readStates = {};
  @tracked readReceiptsEnabled = false;
  @tracked pollsEnabled = false;
  // The holder topic whose core /polls/<id> MessageBus channel carries votes.
  pollsChannelTopicId = null;
  store = new KeyValueStore(STORE_NAMESPACE);

  // Message id a notification deep link (#m<id>) asked to land on. Set by
  // the route/drawer opener, consumed once by the conversation component.
  pendingJumpId = null;

  // True while the timeline shows a window around a searched message rather

  lastTypingSentAt = 0;

  latestMessageId = null;
  lastReadMessageId = null;
  subscribed = false;
  viewing = false;
  loadPromise = null;
  // Read cursor as it stood when the conversation was opened; the timeline

  listeners = new Set();

  onRealtime = (payload) => {
    if (payload?.type === "listened" && payload.message_id) {
      const message = this.messages.find((m) => m.id === payload.message_id);
      if (
        message &&
        !(message.listened_by || []).some((u) => u.id === payload.user_id)
      ) {
        this.upsert({
          ...message,
          listened_by: [
            ...(message.listened_by || []),
            {
              id: payload.user_id,
              username: payload.username,
              name: payload.name,
              avatar_template: payload.avatar_template,
              listened_at: new Date().toISOString(),
            },
          ],
        });
      }
      return;
    }
    if (payload?.type === "read" && payload.user_id) {
      if (payload.user_id !== this.currentUser?.id) {
        this.readStates = {
          ...this.readStates,
          [payload.user_id]: {
            username: payload.username,
            name: payload.name,
            avatar_template: payload.avatar_template,
            last_read_message_id: payload.last_read_message_id,
            updated_at: payload.updated_at,
          },
        };
      }
      return;
    }
    if (!payload?.message) {
      return;
    }
    if (payload.type === "created" && this.detached) {
      this.latestMessageId = Math.max(
        this.latestMessageId || 0,
        payload.message.id
      );
      if (payload.message.user?.id !== this.currentUser.id) {
        this.unreadCount += 1;
      }
      return;
    }
    if (payload.type === "created") {
      this.clearTyper(payload.message.user?.id);
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

  // ── typing ────────────────────────────────────────────────────────────────
  onTyping = (payload) => {
    if (!payload?.user_id || payload.user_id === this.currentUser?.id) {
      return;
    }
    const until = Date.now() + TYPING_TTL;
    const others = this.typers.filter((t) => t.user_id !== payload.user_id);
    this.typers = [...others, { ...payload, until }];
    clearTimeout(this.typingSweep);
    this.typingSweep = setTimeout(() => this.sweepTypers(), TYPING_TTL + 50);
  };

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

  // Ask whichever conversation is (or becomes) visible to jump to a message.
  // A mounted conversation reacts to the app event immediately; one mounted
  // later picks the id up from pendingJumpId in its open sequence.
  requestJump(messageId) {
    const id = parseInt(messageId, 10);
    if (!id) {
      return;
    }
    this.pendingJumpId = id;
    this.appEvents.trigger("disteleplus:jump-to-message", id);
  }

  consumePendingJump() {
    const id = this.pendingJumpId;
    this.pendingJumpId = null;
    return id;
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
        this.readReceiptsEnabled = !!response.meta.read_receipts_enabled;
        this.pollsEnabled = !!response.meta.polls_enabled;
        this.loaded = true;
        this.subscribe();
        if (response.meta.polls_topic_id) {
          this.ensurePollChannel(response.meta.polls_topic_id);
        }
        if (this.readReceiptsEnabled) {
          this.loadReadStates();
        }
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
    this.messageBus.subscribe(TYPING_CHANNEL, this.onTyping);
    this.subscribed = true;
  }

  sweepTypers() {
    const now = Date.now();
    this.typers = this.typers.filter((t) => t.until > now);
    if (this.typers.length) {
      this.typingSweep = setTimeout(() => this.sweepTypers(), 1000);
    }
  }

  clearTyper(userId) {
    this.typers = this.typers.filter((t) => t.user_id !== userId);
  }

  sendTyping() {
    const now = Date.now();
    if (now - this.lastTypingSentAt < TYPING_THROTTLE) {
      return;
    }
    this.lastTypingSentAt = now;
    ajax(`${BASE}/typing`, { type: "POST" }).catch(() => {});
  }

  // ── read receipts ─────────────────────────────────────────────────────────

  async loadReadStates() {
    try {
      const response = await ajax(`${BASE}/read-states`);
      const map = {};
      (response.read_states || []).forEach((state) => {
        map[state.user_id] = state;
      });
      this.readStates = map;
    } catch {
      // Receipts are decoration — the conversation works without them.
    }
  }

  // Everyone (other than self) whose read cursor has passed `messageId`.
  seenBy(messageId) {
    return Object.values(this.readStates).filter(
      (state) => state.last_read_message_id >= messageId
    );
  }

  // First play of a voice note — record the sender's "listened" receipt.
  // One shot per message per session; the server dedupes across sessions.
  listenedSent = new Set();

  markListened(messageId) {
    if (!this.readReceiptsEnabled || this.listenedSent.has(messageId)) {
      return;
    }
    this.listenedSent.add(messageId);
    ajax(`${BASE}/messages/${messageId}/listened`, { type: "POST" }).catch(() =>
      this.listenedSent.delete(messageId)
    );
  }

  // ── search / jump ─────────────────────────────────────────────────────────

  toggleSearch(open = !this.searchOpen) {
    this.searchOpen = open;
    if (!open) {
      this.searchTerm = "";
      this.searchResults = null;
    }
  }

  async search(term) {
    this.searchTerm = term;
    if (term.trim().length < 2) {
      this.searchResults = null;
      return;
    }
    this.searching = true;
    try {
      const response = await ajax(`${BASE}/search`, { data: { q: term } });
      if (this.searchTerm === term) {
        this.searchResults = response.results.map((m) => this.hydrate(m));
      }
    } finally {
      this.searching = false;
    }
  }

  // Replace the timeline with a window around `id` (search result jump).
  async loadAround(id) {
    const response = await ajax(`${BASE}/messages`, {
      data: { around_id: id, limit: 40 },
    });
    this.messages = response.messages.map((m) => this.hydrate(m));
    this.hasMore = response.meta.has_more;
    this.detached = !!response.meta.has_newer;
    return this.messages;
  }

  // Back to the live tail after a detached jump.
  async reloadLatest() {
    this.loaded = false;
    this.detached = false;
    await this.ensureLoaded();
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
    // The holder topic is created lazily with the FIRST poll — a message
    // arriving with a poll may carry a channel we aren't listening to yet.
    if (message.poll?.topic_id) {
      this.ensurePollChannel(message.poll.topic_id);
    }
    return message;
  }

  // ── polls ─────────────────────────────────────────────────────────────────
  // Votes are core discourse-poll votes on the backing post; results stream
  // over core's /polls/<holder topic id> channel.

  ensurePollChannel(topicId) {
    if (!topicId || this.pollsChannelTopicId === topicId) {
      return;
    }
    if (this.pollsChannelTopicId) {
      this.messageBus.unsubscribe(
        `/polls/${this.pollsChannelTopicId}`,
        this.onPollUpdate
      );
    }
    this.pollsChannelTopicId = topicId;
    this.messageBus.subscribe(`/polls/${topicId}`, this.onPollUpdate);
  }

  onPollUpdate = (payload) => {
    const corePoll = (payload?.polls || [])[0];
    if (!corePoll || !payload.post_id) {
      return;
    }
    const message = this.messages.find(
      (candidate) => candidate.poll?.post_id === payload.post_id
    );
    if (message) {
      this.applyCorePoll(message, corePoll);
    }
  };

  // Merge core's serialized poll into our message-local shape. `chosenSet`
  // comes from a vote response; bus updates carry no per-user votes, so the
  // previous chosen flags are preserved there.
  applyCorePoll(message, corePoll, chosenSet = null) {
    const previous = message.poll || {};
    const chosen =
      chosenSet ||
      new Set(
        (previous.options || [])
          .filter((option) => option.chosen)
          .map((option) => option.id)
      );
    const previousById = {};
    (previous.options || []).forEach((option) => {
      previousById[option.id] = option;
    });
    // Public polls carry per-option voters (core's preloaded_voters, keyed
    // by option digest); keep the last known list when a payload lacks it.
    const preloadedVoters = corePoll.preloaded_voters || null;
    const poll = {
      ...previous,
      status: corePoll.status || previous.status,
      closed: (corePoll.status || previous.status) !== "open",
      close_at: corePoll.close || previous.close_at,
      voters: corePoll.voters ?? previous.voters,
      options: (corePoll.options || previous.options || []).map((option) => ({
        id: option.id,
        html: option.html,
        votes: option.votes ?? 0,
        chosen: chosen.has(option.id),
        voters:
          (preloadedVoters
            ? preloadedVoters[option.id]
            : previousById[option.id]?.voters) || [],
      })),
    };
    const next = { ...message, poll };
    this.messages = this.messages.map((candidate) =>
      candidate.id === next.id ? next : candidate
    );
  }

  async votePoll(message, optionIds) {
    const response = await ajax("/polls/vote", {
      type: "PUT",
      data: {
        post_id: message.poll.post_id,
        poll_name: message.poll.name,
        options: optionIds,
      },
    });
    this.applyCorePoll(
      message,
      response.poll || {},
      new Set(response.vote || optionIds)
    );
  }

  async retractPollVote(message) {
    const response = await ajax("/polls/vote", {
      type: "DELETE",
      data: { post_id: message.poll.post_id, poll_name: message.poll.name },
    });
    this.applyCorePoll(message, response.poll || {}, new Set());
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
    const name = (upload.original_filename || "").toLowerCase();
    // Browser recorders produce voice-note-*.webm / .m4a; webm without pixel
    // dimensions is audio, not video.
    const voiceNote = name.startsWith("voice-note") || name === "voice.ogg";
    const dimensionless = !upload.width && !upload.height;
    let kind = "document";
    if (IMAGE_EXTENSIONS.has(extension)) {
      kind = "image";
    } else if (
      voiceNote ||
      AUDIO_EXTENSIONS.has(extension) ||
      (extension === "webm" && dimensionless)
    ) {
      kind = "audio";
    } else if (VIDEO_EXTENSIONS.has(extension)) {
      kind = "video";
    }
    // The served URL is a sha name — voice-ness must ride along explicitly.
    return { ...upload, kind, voice: voiceNote };
  }
}
