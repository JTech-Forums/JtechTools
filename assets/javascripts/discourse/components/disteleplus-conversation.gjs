import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import { emojiSearch } from "pretty-text/emoji";
import { eq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import EmojiAutocompleteResults from "discourse/components/emoji-autocomplete-results";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import UserAutocompleteResults from "discourse/components/user-autocomplete-results";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getAbsoluteURL } from "discourse/lib/get-url";
import lightbox from "discourse/lib/lightbox";
import { emojiUrlFor } from "discourse/lib/text";
import { TextareaAutocompleteHandler } from "discourse/lib/textarea-text-manipulation";
import userSearch, { validateSearchResult } from "discourse/lib/user-search";
import dAutocomplete from "discourse/ui-kit/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";
import { enhanceWithin } from "../lib/disteleplus-voice-player";
import DisteleplusMessageInfo from "./disteleplus-message-info";
import DisteleplusVoiceRecorder from "./disteleplus-voice-recorder";

const EMOJI_CONTEXT = "disteleplus";
const DEFAULT_QUICK_REACTIONS = ["+1", "heart", "laughing", "fire", "tada"];
const MAX_UPLOADS = 10;

// Single-room conversation in Discourse Chat's visual language, with a
// right-click / ⋯ context menu per message, quick reactions plus the full
// core emoji picker, @mention and :emoji: autocomplete in the composer,
// paste/drag-drop uploads, a draft that survives navigation, and a lightbox
// for images.
export default class DisteleplusConversation extends Component {
  @service disteleplus;
  @service appEvents;
  @service dialog;
  @service menu;
  @service emojiStore;
  @service composer;
  @service siteSettings;
  @service site;
  @service router;

  @tracked uploads = [];
  @tracked uploading = false;
  @tracked replyMessage = null;
  @tracked editingMessage = null;
  @tracked newBelow = 0;
  @tracked showJump = false;
  @tracked dragging = false;
  @tracked recordingVoice = false;
  // { message, x, y } while a context menu is open.
  @tracked contextMenu = null;

  element = null;
  timeline = null;
  textarea = null;
  unsubscribe = null;

  // images rendered later (realtime, older pages) get handlers too.
  lightboxUploads = modifier((element) => {
    if (element.querySelector(".lightbox")) {
      lightbox(element, this.siteSettings);
    }
  });

  // imperatively on insert rather than as a template modifier.
  autocompletes = [];

  willDestroy() {
    super.willDestroy(...arguments);
    this.teardownAutocomplete();
    this.unsubscribe?.();
    document.removeEventListener("click", this.closeContextMenu);
    document.removeEventListener("keydown", this.onDocumentKeydown);
    window.removeEventListener("hashchange", this.onHashChange);
    this.appEvents.off("disteleplus:jump-to-message", this, this.jumpToId);
    this.disteleplus.setViewing(false);
  }

  get draft() {
    return this.disteleplus.draft;
  }

  get cannotSend() {
    return (
      this.disteleplus.sending ||
      this.uploading ||
      (!this.draft.trim() && this.uploads.length === 0)
    );
  }

  get quickReactions() {
    let favorites = [];
    try {
      favorites = this.emojiStore.favoritesForContext(EMOJI_CONTEXT) || [];
    } catch {
      favorites = [];
    }
    const names = [...favorites, ...DEFAULT_QUICK_REACTIONS]
      .filter((name, index, list) => list.indexOf(name) === index)
      .slice(0, 6);
    return names.map((name) => ({ name, url: emojiUrlFor(name) }));
  }

  // Timeline rows: messages interleaved with date separators and, once, the
  // unread divider (after the read cursor as it stood when the page opened).
  get rows() {
    const rows = [];
    let lastDay = null;
    let dividerPlaced = false;
    let previous = null;
    const readId = this.disteleplus.openedAtReadId || 0;
    for (const message of this.disteleplus.messages) {
      const day = message.createdDate.toDateString();
      if (day !== lastDay) {
        previous = null;
        rows.push({
          kind: "date",
          key: `date-${day}`,
          label: this.day(message.createdDate),
        });
        lastDay = day;
      }
      if (!dividerPlaced && readId && message.id > readId && !message.mine) {
        rows.push({ kind: "unread", key: "unread" });
        dividerPlaced = true;
        previous = null;
      }
      // Same sender within five minutes: collapse avatar and name.
      const continued =
        previous &&
        previous.user?.id === message.user?.id &&
        previous.external_sender_name === message.external_sender_name &&
        message.createdDate - previous.createdDate < 5 * 60 * 1000;
      rows.push({ kind: "message", key: message.id, message, continued });
      previous = message;
    }
    return rows;
  }

  get nearBottom() {
    const element = this.timeline;
    if (!element) {
      return true;
    }
    return (
      element.scrollHeight - element.scrollTop - element.clientHeight < 100
    );
  }

  get contextMenuStyle() {
    if (!this.contextMenu) {
      return htmlSafe("");
    }
    return htmlSafe(
      `left:${Math.round(this.contextMenu.x)}px;top:${Math.round(
        this.contextMenu.y
      )}px`
    );
  }

  get showFullPageNavbar() {
    return !this.args.inDrawer && !this.site.mobileView;
  }

  get voiceNotesEnabled() {
    return !!this.siteSettings.disteleplus_voice_notes_enabled;
  }

  // Chat's navbar OpenDrawerButton: leave full page, continue in the drawer.
  @action
  async openInDrawer() {
    this.disteleplus.prefersDrawer();
    const url = this.disteleplus.lastAppURL || "/";
    try {
      await this.router.transitionTo(url);
    } catch {
      // TransitionAborted is expected when another transition supersedes it.
    }
    this.disteleplus.openDrawer();
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @action
  mount(element) {
    this.element = element;
    this.timeline = element.querySelector(".disteleplus-timeline");
    this.disteleplus.setViewing(true);
    this.unsubscribe = this.disteleplus.onNewMessage(this.onNewMessage);
    document.addEventListener("click", this.closeContextMenu);
    document.addEventListener("keydown", this.onDocumentKeydown);
    // A notification clicked while the conversation is already open only
    // changes the hash / fires the jump event — no remount happens.
    window.addEventListener("hashchange", this.onHashChange);
    this.appEvents.on("disteleplus:jump-to-message", this, this.jumpToId);
    element.addEventListener("disteleplus:voice-played", this.onVoicePlayed);
    requestAnimationFrame(() => {
      this.openAtStart();
      this.enhance(element);
    });
  }

  // Deep link (#m123, or one stashed by the route/drawer opener) wins;
  // otherwise land on the unread divider like Telegram does; otherwise the
  // bottom.
  async openAtStart() {
    const match = window.location.hash.match(/^#m(\d+)$/);
    const targetId =
      this.disteleplus.consumePendingJump() || (match && Number(match[1]));
    if (targetId && (await this.jumpToId(targetId))) {
      return;
    }
    const divider = this.timeline?.querySelector(
      ".disteleplus-separator.is-unread"
    );
    if (divider) {
      divider.scrollIntoView({ block: "start" });
      this.showJump = !this.nearBottom;
      return;
    }
    this.scrollToBottom();
  }

  @action
  onHashChange() {
    const match = window.location.hash.match(/^#m(\d+)$/);
    if (match) {
      this.jumpToId(Number(match[1]));
    }
  }

  // Scroll to and highlight a message by id, fetching a window around it
  // when it isn't in the loaded slice. Resolves true when the message was
  // found (locally or remotely).
  @action
  async jumpToId(id) {
    // Consume a matching stash so a later mount doesn't replay the jump.
    if (this.disteleplus.pendingJumpId === id) {
      this.disteleplus.consumePendingJump();
    }
    if (!this.messageElement(id)) {
      try {
        await this.disteleplus.loadAround(id);
      } catch {
        return false;
      }
      await new Promise((resolve) => requestAnimationFrame(resolve));
      this.enhance(this.timeline);
    }
    const target = this.messageElement(id);
    if (!target) {
      return false;
    }
    this.highlight(target);
    this.showJump = !this.nearBottom;
    return true;
  }

  enhance(root) {
    enhanceWithin(root, {
      allAudio: !!this.siteSettings.disteleplus_voice_player_all_audio,
    });
  }

  @action
  onNewMessage(message, { mine }) {
    if (mine || this.nearBottom) {
      requestAnimationFrame(() => this.scrollToBottom());
    } else {
      this.newBelow += 1;
    }
    requestAnimationFrame(() => this.enhance(this.timeline));
  }

  // ── composer ──────────────────────────────────────────────────────────────

  @action
  updateDraft(event) {
    this.disteleplus.setDraft(event.target.value);
    this.autosize(event.target);
    if (event.target.value.trim()) {
      this.disteleplus.sendTyping();
    }
  }

  get typingLabel() {
    const typers = this.disteleplus.typers;
    if (!typers.length) {
      return null;
    }
    const label = (t) => t.name || t.username;
    if (typers.length === 1) {
      return i18n("disteleplus.typing_one", { name: label(typers[0]) });
    }
    if (typers.length === 2) {
      return i18n("disteleplus.typing_two", {
        a: label(typers[0]),
        b: label(typers[1]),
      });
    }
    return i18n("disteleplus.typing_many", { count: typers.length });
  }

  // Telegram-style double tap: react with your first quick reaction.
  @action
  doubleTap(message, event) {
    if (message.deleted) {
      return;
    }
    if (event.target.closest("a, button, audio, video, img, .lightbox")) {
      return;
    }
    event.preventDefault();
    const emoji = this.quickReactions[0]?.name || "heart";
    const el = this.messageElement(message.id);
    el?.classList.add("is-pop");
    window.setTimeout(() => el?.classList.remove("is-pop"), 600);
    this.react(message, emoji);
  }

  // ── search ────────────────────────────────────────────────────────────────

  @action
  toggleSearch() {
    this.disteleplus.toggleSearch();
    if (this.disteleplus.searchOpen) {
      requestAnimationFrame(() =>
        this.element?.querySelector(".disteleplus-search input")?.focus()
      );
    }
  }

  @action
  onSearchInput(event) {
    this.disteleplus.search(event.target.value).catch(popupAjaxError);
  }

  @action
  onSearchKeydown(event) {
    if (event.key === "Escape") {
      this.disteleplus.toggleSearch(false);
    }
  }

  @action
  async openResult(result) {
    this.disteleplus.toggleSearch(false);
    await this.jumpToId(result.id);
  }

  autosize(textarea) {
    textarea.style.height = "auto";
    textarea.style.height = `${Math.min(textarea.scrollHeight, 200)}px`;
  }

  @action
  composerKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      // Let an open autocomplete menu take the Enter key.
      if (document.querySelector('[data-identifier="d-autocomplete"]')) {
        return;
      }
      event.preventDefault();
      this.send();
    } else if (
      event.key === "Escape" &&
      (this.replyMessage || this.editingMessage)
    ) {
      this.cancelContext();
    } else if (event.key === "ArrowUp" && !this.draft && !this.editingMessage) {
      // Telegram: up-arrow in an empty composer edits your last message.
      const mine = [...this.disteleplus.messages]
        .reverse()
        .find((message) => message.mine && message.can_edit);
      if (mine) {
        event.preventDefault();
        this.startEdit(mine);
      }
    }
  }

  @action
  async send() {
    if (this.cannotSend) {
      return;
    }
    try {
      if (this.editingMessage) {
        await this.disteleplus.updateMessage(
          this.editingMessage.id,
          this.draft.trim()
        );
      } else {
        await this.disteleplus.createMessage({
          raw: this.draft.trim(),
          uploadIds: this.uploads.map((upload) => upload.id),
          replyToId: this.replyMessage?.id,
        });
      }
      this.cancelContext();
      this.uploads = [];
      if (this.textarea) {
        this.textarea.style.height = "auto";
      }
      requestAnimationFrame(() => this.scrollToBottom());
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  startReply(message) {
    this.editingMessage = null;
    this.replyMessage = message;
    this.textarea?.focus();
  }

  @action
  startEdit(message) {
    this.replyMessage = null;
    this.editingMessage = message;
    this.disteleplus.setDraft(message.raw);
    requestAnimationFrame(() => {
      if (this.textarea) {
        this.autosize(this.textarea);
        this.textarea.focus();
        this.textarea.setSelectionRange(
          this.textarea.value.length,
          this.textarea.value.length
        );
      }
    });
  }

  @action
  cancelContext() {
    const wasEditing = !!this.editingMessage;
    this.replyMessage = null;
    this.editingMessage = null;
    if (wasEditing) {
      this.disteleplus.setDraft("");
    }
  }

  @action
  insertEmoji(event) {
    this.menu.show(event.currentTarget, {
      identifier: "disteleplus-emoji-picker",
      groupIdentifier: "emoji-picker",
      component: EmojiPickerDetached,
      modalForMobile: true,
      placement: "top-end",
      fallbackPlacements: ["top-start", "bottom-end"],
      data: {
        context: EMOJI_CONTEXT,
        didSelectEmoji: (emoji) => this.insertText(`:${emoji}: `),
      },
    });
  }

  insertText(text) {
    const textarea = this.textarea;
    if (!textarea) {
      this.disteleplus.setDraft(`${this.draft}${text}`);
      return;
    }
    const start = textarea.selectionStart ?? textarea.value.length;
    const end = textarea.selectionEnd ?? start;
    const value = textarea.value;
    const next = value.slice(0, start) + text + value.slice(end);
    this.disteleplus.setDraft(next);
    requestAnimationFrame(() => {
      textarea.value = next;
      textarea.setSelectionRange(start + text.length, start + text.length);
      textarea.focus();
      this.autosize(textarea);
    });
  }

  // Autocomplete — wired exactly like Chat's composer: the modifier needs a
  // TextareaAutocompleteHandler as its textHandler, so it is set up

  @action
  setupComposerTextarea(textarea) {
    this.textarea = textarea;
    this.autosize(textarea);
    const handler = new TextareaAutocompleteHandler(textarea);
    const apply = (options) =>
      dAutocomplete.setupAutocomplete(getOwner(this), textarea, handler, {
        treatAsTextarea: true,
        fixedTextareaPosition: true,
        ...options,
      });

    if (this.siteSettings.enable_mentions) {
      this.autocompletes.push(
        apply({
          component: UserAutocompleteResults,
          key: UserAutocompleteResults.TRIGGER_KEY,
          width: "100%",
          autoSelectFirstSuggestion: true,
          transformComplete: (result) => {
            validateSearchResult(result);
            return result.username || result.name;
          },
          dataSource: (term) => userSearch({ term, includeGroups: true }),
          afterComplete: (text, event) => {
            event?.preventDefault?.();
            this.disteleplus.setDraft(text);
            textarea.focus();
          },
        })
      );
    }

    if (this.siteSettings.enable_emoji) {
      this.autocompletes.push(
        apply({
          component: EmojiAutocompleteResults,
          key: EmojiAutocompleteResults.TRIGGER_KEY,
          onKeyUp: (text, caret) => {
            const matches =
              /(?:^|[\s.?,@/#!%&*;:[\]{}=\-_()+])(:(?!:).?[\w-]*:?(?!:)(?:t\d?)?:?)$/gi.exec(
                text.substring(0, caret)
              );
            return matches?.[1] ? [matches[1]] : undefined;
          },
          transformComplete: (result) => `${result.code}:`,
          dataSource: (term) => {
            if (!term || term.length < 2) {
              return [];
            }
            return emojiSearch(term, {
              maxResults: 6,
              diversity: this.emojiStore?.diversity,
            }).map((code) => ({ code, src: emojiUrlFor(code) }));
          },
          afterComplete: (text, event) => {
            event?.preventDefault?.();
            this.disteleplus.setDraft(text);
            textarea.focus();
          },
        })
      );
    }
  }

  teardownAutocomplete() {
    this.autocompletes.forEach((instance) => instance.cleanup?.());
    this.autocompletes = [];
  }

  // ── uploads ───────────────────────────────────────────────────────────────

  @action
  pickFiles(event) {
    const files = [...event.target.files];
    event.target.value = "";
    this.addFiles(files);
  }

  @action
  onPaste(event) {
    const files = [...(event.clipboardData?.files || [])];
    if (files.length) {
      event.preventDefault();
      this.addFiles(files);
    }
  }

  @action
  onDragOver(event) {
    if ([...(event.dataTransfer?.types || [])].includes("Files")) {
      event.preventDefault();
      this.dragging = true;
    }
  }

  @action
  onDragLeave(event) {
    if (!this.element?.contains(event.relatedTarget)) {
      this.dragging = false;
    }
  }

  @action
  onDrop(event) {
    event.preventDefault();
    this.dragging = false;
    this.addFiles([...(event.dataTransfer?.files || [])]);
  }

  async addFiles(files) {
    if (!files.length) {
      return;
    }
    this.uploading = true;
    try {
      for (const file of files.slice(0, MAX_UPLOADS - this.uploads.length)) {
        const form = new FormData();
        form.append("type", "composer");
        form.append("file", file, file.name);
        const response = await ajax("/uploads.json", {
          type: "POST",
          data: form,
          processData: false,
          contentType: false,
        });
        this.uploads = [...this.uploads, response];
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.uploading = false;
    }
  }

  @action
  removeUpload(upload) {
    // By object, not id: Discourse dedupes identical files to one upload id,
    // so attaching the same picture twice gives two rows with equal ids —
    // an id filter removed both when either X was clicked.
    this.uploads = this.uploads.filter((candidate) => candidate !== upload);
  }

  @action
  openVoiceRecorder() {
    this.teardownAutocomplete();
    this.recordingVoice = true;
  }

  @action
  closeVoiceRecorder() {
    this.recordingVoice = false;
    requestAnimationFrame(() => this.textarea?.focus());
  }

  @action
  voiceNoteSent(message) {
    this.recordingVoice = false;
    if (message) {
      this.disteleplus.upsert(message);
    }
    requestAnimationFrame(() => this.scrollToBottom());
  }

  // Same as Chat's message collapser: init the lightbox per uploads block so

  // ── message actions ───────────────────────────────────────────────────────

  @action
  openContextMenu(message, event) {
    event.preventDefault();
    event.stopPropagation();
    const bounds = this.element.getBoundingClientRect();
    let x = event.clientX - bounds.left;
    let y = event.clientY - bounds.top;
    if (event.type !== "contextmenu") {
      // Anchored under the ⋯ button instead of the pointer.
      const rect = event.currentTarget.getBoundingClientRect();
      x = rect.right - bounds.left;
      y = rect.bottom - bounds.top;
    }
    x = Math.min(x, bounds.width - 230);
    y = Math.min(y, bounds.height - 320);
    this.contextMenu = { message, x: Math.max(8, x), y: Math.max(8, y) };
  }

  @action
  closeContextMenu() {
    this.contextMenu = null;
  }

  @action
  onDocumentKeydown(event) {
    if (event.key === "Escape" && this.contextMenu) {
      this.closeContextMenu();
    }
  }

  @action
  async react(message, emoji) {
    this.closeContextMenu();
    try {
      this.emojiStore?.trackEmojiForContext?.(emoji, EMOJI_CONTEXT);
      await this.disteleplus.toggleReaction(message, emoji);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  pickReaction(message, event) {
    event.stopPropagation();
    this.closeContextMenu();
    // Anchor to the message row, not the button: the hover toolbar is
    // invisible when the pointer leaves it and the context menu is removed
    // from the DOM the moment it closes — both make useless anchors.
    const anchor = this.messageElement(message.id) || event.currentTarget;
    this.menu.show(anchor, {
      identifier: "disteleplus-reaction-picker",
      groupIdentifier: "emoji-picker",
      component: EmojiPickerDetached,
      modalForMobile: true,
      placement: "top-start",
      fallbackPlacements: ["bottom-start", "top-end", "bottom-end"],
      data: {
        context: EMOJI_CONTEXT,
        didSelectEmoji: (emoji) => this.react(message, emoji),
      },
    });
  }

  @action
  copyText(message) {
    this.closeContextMenu();
    navigator.clipboard?.writeText(message.raw || "");
  }

  @action
  copyLink(message) {
    this.closeContextMenu();
    navigator.clipboard?.writeText(
      `${getAbsoluteURL("/disteleplus")}#m${message.id}`
    );
  }

  @action
  quoteInTopic(message) {
    this.closeContextMenu();
    const author = this.sender(message);
    const body = `[quote="${author}"]\n${message.raw}\n[/quote]\n\n`;
    this.composer.openNewTopic({ body });
  }

  @action
  remove(message) {
    this.closeContextMenu();
    this.dialog.deleteConfirm({
      message: i18n("disteleplus.delete_confirm"),
      didConfirm: async () => {
        try {
          await this.disteleplus.deleteMessage(message.id);
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  menuReply(message) {
    this.closeContextMenu();
    this.startReply(message);
  }

  @action
  menuEdit(message) {
    this.closeContextMenu();
    this.startEdit(message);
  }

  // ── scrolling ─────────────────────────────────────────────────────────────

  @action
  async onScroll(event) {
    const element = event.currentTarget;
    const nearBottom =
      element.scrollHeight - element.scrollTop - element.clientHeight < 100;
    this.showJump = !nearBottom;
    if (nearBottom) {
      this.newBelow = 0;
      this.disteleplus.markRead();
    }
    if (element.scrollTop > 100 || !this.disteleplus.hasMore) {
      return;
    }

    const oldHeight = element.scrollHeight;
    const older = await this.disteleplus.loadOlder();
    if (older.length) {
      requestAnimationFrame(() => {
        element.scrollTop = element.scrollHeight - oldHeight;
        this.enhance(element);
      });
    }
  }

  @action
  async scrollToBottom() {
    if (this.disteleplus.detached) {
      await this.disteleplus.reloadLatest();
      await new Promise((resolve) => requestAnimationFrame(resolve));
    }
    if (this.timeline) {
      this.timeline.scrollTop = this.timeline.scrollHeight;
      this.newBelow = 0;
      this.showJump = false;
      this.disteleplus.markRead();
      this.enhance(this.timeline);
    }
  }

  @action
  jumpTo(message) {
    // jumpToId loads a window around out-of-view targets (old replies,
    // deep links) instead of silently doing nothing.
    this.jumpToId(message.id);
  }

  messageElement(id) {
    return document.getElementById(`disteleplus-message-${id}`);
  }

  highlight(target) {
    target.scrollIntoView({ behavior: "smooth", block: "center" });
    target.classList.add("is-highlighted");
    window.setTimeout(() => target.classList.remove("is-highlighted"), 1500);
  }

  // ── formatting helpers ────────────────────────────────────────────────────

  safeCooked(cooked) {
    return htmlSafe(cooked || "");
  }

  avatarUrl(template) {
    return template?.replace("{size}", "48") || "";
  }

  day(date) {
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(today.getDate() - 1);
    if (date.toDateString() === today.toDateString()) {
      return i18n("disteleplus.today");
    }
    if (date.toDateString() === yesterday.toDateString()) {
      return i18n("disteleplus.yesterday");
    }
    return new Intl.DateTimeFormat(undefined, {
      weekday: "short",
      month: "short",
      day: "numeric",
      year: date.getFullYear() === today.getFullYear() ? undefined : "numeric",
    }).format(date);
  }

  time(date) {
    return new Intl.DateTimeFormat(undefined, {
      hour: "numeric",
      minute: "2-digit",
    }).format(date);
  }

  bytes(value) {
    const bytes = Number(value || 0);
    if (bytes < 1024 * 1024) {
      return `${Math.max(1, Math.round(bytes / 1024))} KB`;
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  sender(message) {
    return (
      message.external_sender_name ||
      message.user?.name ||
      message.user?.username ||
      i18n("disteleplus.telegram_user")
    );
  }

  reactionTitle(reaction) {
    const names = (reaction.users || []).map(
      (user) => user.name || user.username
    );
    return names.length ? `:${reaction.emoji}: — ${names.join(", ")}` : "";
  }

  // ── read receipts ─────────────────────────────────────────────────────────
  // Telegram-style: the chip lives on the current user's latest message
  // only — once a reader's cursor passes it, everything above is seen by
  // definition.

  get receiptMessageId() {
    if (!this.disteleplus.readReceiptsEnabled) {
      return null;
    }
    const messages = this.disteleplus.messages;
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].mine && !messages[i].deleted) {
        return messages[i].id;
      }
    }
    return null;
  }

  get receiptSeenBy() {
    const id = this.receiptMessageId;
    return id ? this.disteleplus.seenBy(id) : [];
  }

  get receiptAvatars() {
    return this.receiptSeenBy.slice(0, 8).map((state) => ({
      username: state.username,
      title: state.name || state.username,
      url: this.avatarUrl(state.avatar_template),
    }));
  }

  get receiptTitle() {
    const names = this.receiptSeenBy.map(
      (state) => state.name || state.username
    );
    return names.join(", ");
  }

  // "Listened by" tooltip for a voice-note message's receipt chip.
  listenTitle(message) {
    return (message.listened_by || [])
      .map((user) => user.name || user.username)
      .join(", ");
  }

  listenAvatars(message) {
    return (message.listened_by || []).slice(0, 8).map((user) => ({
      username: user.username,
      url: this.avatarUrl(user.avatar_template),
    }));
  }

  // WhatsApp-style message info: who saw / listened, and when.
  @action
  openMessageInfo(message) {
    this.modal.show(DisteleplusMessageInfo, { model: { message } });
  }

  // Bubbled from the voice player on first play — record the receipt.
  @action
  onVoicePlayed(event) {
    const wrapper = event.target.closest("[id^='disteleplus-message-']");
    const id = Number(wrapper?.id?.replace("disteleplus-message-", ""));
    if (id) {
      this.disteleplus.markListened(id);
    }
  }

  <template>
    <section
      class="disteleplus-page
        {{if @inDrawer 'in-drawer' 'full-page'}}
        {{if this.showFullPageNavbar 'has-navbar'}}
        {{if this.dragging 'is-dragging'}}"
      {{didInsert this.mount}}
      {{on "dragover" this.onDragOver}}
      {{on "dragleave" this.onDragLeave}}
      {{on "drop" this.onDrop}}
    >
      {{#if this.showFullPageNavbar}}
        <div class="disteleplus-navbar-container">
          <nav class="disteleplus-navbar">
            <div class="disteleplus-navbar__title">
              {{icon "comments"}}
              <span>{{i18n "disteleplus.title"}}</span>
            </div>
            <div class="disteleplus-navbar__actions">
              <DButton
                @icon="magnifying-glass"
                @action={{this.toggleSearch}}
                @title="disteleplus.search"
                class="btn-transparent no-text
                  {{if this.disteleplus.searchOpen 'active'}}"
              />
              <DButton
                @icon="discourse-compress"
                @action={{this.openInDrawer}}
                @title="disteleplus.open_in_drawer"
                class="btn-transparent no-text"
              />
            </div>
          </nav>
        </div>
      {{/if}}
      {{#if this.disteleplus.searchOpen}}
        <div class="disteleplus-search">
          <div class="disteleplus-search__bar">
            {{icon "magnifying-glass"}}
            <input
              type="search"
              value={{this.disteleplus.searchTerm}}
              placeholder={{i18n "disteleplus.search_placeholder"}}
              {{on "input" this.onSearchInput}}
              {{on "keydown" this.onSearchKeydown}}
            />
            <button
              type="button"
              title={{i18n "disteleplus.close"}}
              {{on "click" this.toggleSearch}}
            >{{icon "xmark"}}</button>
          </div>
          {{#if this.disteleplus.searchResults}}
            <div class="disteleplus-search__results">
              {{#each this.disteleplus.searchResults as |result|}}
                <button
                  type="button"
                  class="disteleplus-search__result"
                  {{on "click" (fn this.openResult result)}}
                >
                  <strong>{{this.sender result}}</strong>
                  <time>{{this.day result.createdDate}}
                    {{this.time result.createdDate}}</time>
                  <span>{{this.safeCooked result.cooked}}</span>
                </button>
              {{else}}
                <div class="disteleplus-search__empty">{{i18n
                    "disteleplus.search_empty"
                  }}</div>
              {{/each}}
            </div>
          {{/if}}
        </div>
      {{/if}}

      <div class="disteleplus-timeline" {{on "scroll" this.onScroll}}>
        {{#if this.disteleplus.loadingOlder}}
          <div class="disteleplus-loading">{{i18n "disteleplus.loading"}}</div>
        {{/if}}

        {{#each this.rows key="key" as |row|}}
          {{#if (eq row.kind "date")}}
            <div class="disteleplus-separator is-date"><span
              >{{row.label}}</span></div>
          {{else if (eq row.kind "unread")}}
            <div class="disteleplus-separator is-unread"><span>{{i18n
                  "disteleplus.unread_divider"
                }}</span></div>
          {{else}}
            {{#let row.message as |message|}}
              {{! template-lint-disable no-invalid-interactive }}
              <article
                id="disteleplus-message-{{message.id}}"
                class="disteleplus-message
                  {{if message.mine 'is-mine'}}
                  {{if message.deleted 'is-deleted'}}
                  {{if message.edited_at 'is-edited'}}
                  {{if row.continued 'is-continued'}}
                  {{if
                    (eq this.contextMenu.message.id message.id)
                    'is-menu-open'
                  }}"
                {{on "contextmenu" (fn this.openContextMenu message)}}
                {{on "dblclick" (fn this.doubleTap message)}}
              >
                {{! Bare #m<id> anchor so /disteleplus#m42 also works through
                    core's jumpToElement and native browser anchoring. }}
                <span
                  id="m{{message.id}}"
                  class="disteleplus-message__hash-anchor"
                  aria-hidden="true"
                ></span>
                <div class="disteleplus-message__avatar">
                  {{#if message.user}}
                    <a
                      href="/u/{{message.user.username}}"
                      data-user-card={{message.user.username}}
                    >
                      <img
                        src={{this.avatarUrl message.user.avatar_template}}
                        alt=""
                        width="36"
                        height="36"
                      />
                    </a>
                  {{else}}
                    {{icon "paper-plane"}}
                  {{/if}}
                </div>
                <div class="disteleplus-message__bubble">
                  <div class="disteleplus-message__meta">
                    <strong>{{this.sender message}}</strong>
                    <span class="disteleplus-message__time">
                      {{#if message.edited_at}}<small>{{i18n
                            "disteleplus.edited"
                          }}</small>{{/if}}
                      <time>{{this.time message.createdDate}}</time>
                    </span>
                  </div>

                  {{#if message.reply_to}}
                    <button
                      type="button"
                      class="disteleplus-message__reply-preview"
                      {{on "click" (fn this.jumpTo message.reply_to)}}
                    >
                      {{#if message.reply_to.thumbnail_url}}
                        <img
                          class="disteleplus-message__reply-thumb"
                          src={{message.reply_to.thumbnail_url}}
                          alt=""
                        />
                      {{/if}}
                      <span class="disteleplus-message__reply-text">
                        <strong>{{this.sender message.reply_to}}</strong>
                        {{#if message.reply_to.deleted}}
                          <span>{{i18n "disteleplus.deleted"}}</span>
                        {{else if message.reply_to.excerpt}}
                          <span>{{message.reply_to.excerpt}}</span>
                        {{else if message.reply_to.attachment_name}}
                          <span>{{icon "paperclip"}}
                            {{message.reply_to.attachment_name}}</span>
                        {{/if}}
                      </span>
                    </button>
                  {{/if}}

                  {{#if message.deleted}}
                    <p class="disteleplus-message__deleted">{{icon "trash-can"}}
                      {{i18n "disteleplus.deleted"}}</p>
                  {{else}}
                    {{#if message.uploads.length}}
                      <div class="disteleplus-uploads" {{this.lightboxUploads}}>
                        {{#each message.uploads as |upload|}}
                          {{#if (eq upload.kind "image")}}
                            <img
                              class="disteleplus-upload is-image lightbox"
                              src={{upload.url}}
                              alt={{upload.original_filename}}
                              title={{upload.original_filename}}
                              data-large-src={{upload.url}}
                              data-download-href={{upload.url}}
                              data-target-width={{upload.width}}
                              data-target-height={{upload.height}}
                              width={{upload.width}}
                              height={{upload.height}}
                              loading="lazy"
                              tabindex="0"
                            />
                          {{else if (eq upload.kind "video")}}
                            <video
                              class="disteleplus-upload is-video"
                              controls
                              preload="metadata"
                            >
                              <source src={{upload.url}} />
                            </video>
                          {{else if (eq upload.kind "audio")}}
                            <div class="disteleplus-upload is-audio">
                              <audio
                                controls
                                preload="metadata"
                                src={{upload.url}}
                              ></audio>
                            </div>
                          {{else}}
                            <a
                              href={{upload.url}}
                              class="disteleplus-upload is-document"
                              download={{upload.original_filename}}
                            >
                              <span class="disteleplus-upload__icon">{{icon
                                  "file"
                                }}</span>
                              <span class="disteleplus-upload__text"><strong
                                >{{upload.original_filename}}</strong><small
                                >{{this.bytes upload.filesize}}</small></span>
                              {{icon "download"}}
                            </a>
                          {{/if}}
                        {{/each}}
                      </div>
                    {{/if}}

                    {{#if message.cooked}}
                      <div class="disteleplus-message__cooked cooked">
                        {{this.safeCooked message.cooked}}
                      </div>
                    {{/if}}
                  {{/if}}

                  {{#if message.reactions.length}}
                    <div class="disteleplus-reactions">
                      {{#each message.reactions as |reaction|}}
                        <button
                          type="button"
                          class={{if reaction.reacted "is-reacted"}}
                          title={{this.reactionTitle reaction}}
                          {{on "click" (fn this.react message reaction.emoji)}}
                        >
                          {{#if reaction.url}}
                            <img
                              src={{reaction.url}}
                              alt=":{{reaction.emoji}}:"
                              class="emoji"
                            />
                          {{else}}
                            {{reaction.display}}
                          {{/if}}
                          <span>{{reaction.count}}</span>
                        </button>
                      {{/each}}
                    </div>
                  {{/if}}

                  {{#if (eq message.id this.receiptMessageId)}}
                    <button
                      type="button"
                      class="disteleplus-message__receipt
                        {{if this.receiptSeenBy.length 'is-seen'}}"
                      title={{this.receiptTitle}}
                      {{on "click" (fn this.openMessageInfo message)}}
                    >
                      {{#if this.receiptSeenBy.length}}
                        {{icon "check-double"}}
                        <span class="disteleplus-message__receipt-label">
                          {{i18n
                            "disteleplus.seen_by"
                            count=this.receiptSeenBy.length
                          }}
                        </span>
                        <span class="disteleplus-message__receipt-avatars">
                          {{#each this.receiptAvatars as |reader|}}
                            <img
                              src={{reader.url}}
                              alt={{reader.username}}
                              title={{reader.title}}
                            />
                          {{/each}}
                        </span>
                      {{else}}
                        {{icon "check"}}
                      {{/if}}
                    </button>
                  {{/if}}

                  {{#if message.mine}}
                    {{#if message.listened_by.length}}
                      <button
                        type="button"
                        class="disteleplus-message__receipt is-seen"
                        title={{this.listenTitle message}}
                        {{on "click" (fn this.openMessageInfo message)}}
                      >
                        {{icon "headphones"}}
                        <span class="disteleplus-message__receipt-label">
                          {{i18n
                            "disteleplus.listened_by"
                            count=message.listened_by.length
                          }}
                        </span>
                        <span class="disteleplus-message__receipt-avatars">
                          {{#each (this.listenAvatars message) as |listener|}}
                            <img
                              src={{listener.url}}
                              alt={{listener.username}}
                              title={{listener.username}}
                            />
                          {{/each}}
                        </span>
                      </button>
                    {{/if}}
                  {{/if}}
                </div>

                {{#unless message.deleted}}
                  <div class="disteleplus-message__actions">
                    <button
                      type="button"
                      title={{i18n "disteleplus.react"}}
                      {{on "click" (fn this.pickReaction message)}}
                    >{{icon "face-smile"}}</button>
                    <button
                      type="button"
                      title={{i18n "disteleplus.reply"}}
                      {{on "click" (fn this.startReply message)}}
                    >{{icon "reply"}}</button>
                    <button
                      type="button"
                      title={{i18n "disteleplus.more"}}
                      aria-haspopup="menu"
                      {{on "click" (fn this.openContextMenu message)}}
                    >{{icon "ellipsis"}}</button>
                  </div>
                {{/unless}}
              </article>
            {{/let}}
          {{/if}}
        {{else}}
          <div class="disteleplus-empty">
            {{icon "comments"}}
            <h2>{{i18n "disteleplus.empty_title"}}</h2>
            <p>{{i18n "disteleplus.empty_body"}}</p>
          </div>
        {{/each}}
      </div>

      {{#if this.contextMenu}}
        {{#let this.contextMenu.message as |message|}}
          <div
            class="disteleplus-context-menu"
            role="menu"
            style={{this.contextMenuStyle}}
          >
            <div class="disteleplus-context-menu__reactions">
              {{#each this.quickReactions as |reaction|}}
                <button
                  type="button"
                  title=":{{reaction.name}}:"
                  {{on "click" (fn this.react message reaction.name)}}
                ><img
                    src={{reaction.url}}
                    alt=":{{reaction.name}}:"
                    class="emoji"
                  /></button>
              {{/each}}
              <button
                type="button"
                class="is-more"
                title={{i18n "disteleplus.react"}}
                {{on "click" (fn this.pickReaction message)}}
              >{{icon "plus"}}</button>
            </div>
            <button
              type="button"
              role="menuitem"
              {{on "click" (fn this.menuReply message)}}
            >{{icon "reply"}} {{i18n "disteleplus.reply"}}</button>
            {{#if message.raw}}
              <button
                type="button"
                role="menuitem"
                {{on "click" (fn this.copyText message)}}
              >{{icon "copy"}} {{i18n "disteleplus.copy_text"}}</button>
            {{/if}}
            <button
              type="button"
              role="menuitem"
              {{on "click" (fn this.copyLink message)}}
            >{{icon "link"}} {{i18n "disteleplus.copy_link"}}</button>
            {{#if message.raw}}
              <button
                type="button"
                role="menuitem"
                {{on "click" (fn this.quoteInTopic message)}}
              >{{icon "quote-right"}}
                {{i18n "disteleplus.quote_in_topic"}}</button>
            {{/if}}
            {{#if message.can_edit}}
              <button
                type="button"
                role="menuitem"
                {{on "click" (fn this.menuEdit message)}}
              >{{icon "pencil"}} {{i18n "disteleplus.edit"}}</button>
            {{/if}}
            {{#if message.can_delete}}
              <button
                type="button"
                role="menuitem"
                class="is-danger"
                {{on "click" (fn this.remove message)}}
              >{{icon "trash-can"}} {{i18n "disteleplus.delete"}}</button>
            {{/if}}
          </div>
        {{/let}}
      {{/if}}

      {{#if this.showJump}}
        <button
          class="disteleplus-jump"
          type="button"
          title={{i18n "disteleplus.go_to_bottom"}}
          aria-label={{i18n "disteleplus.go_to_bottom"}}
          {{on "click" this.scrollToBottom}}
        >
          {{icon "arrow-down"}}
          {{#if this.newBelow}}<span>{{this.newBelow}}</span>{{/if}}
        </button>
      {{/if}}

      {{#if this.dragging}}
        <div class="disteleplus-drop">{{icon "upload"}}
          {{i18n "disteleplus.drop_files"}}</div>
      {{/if}}

      <footer class="disteleplus-composer">
        <div class="disteleplus-typing">
          {{#if this.typingLabel}}
            <span class="disteleplus-typing__text">{{this.typingLabel}}</span>
            <span class="disteleplus-typing__wave"><span></span><span
              ></span><span></span></span>
          {{/if}}
        </div>
        {{#if (or this.replyMessage this.editingMessage)}}
          <div class="disteleplus-composer__context">
            {{icon (if this.editingMessage "pencil" "reply")}}
            <span>
              <strong>{{#if this.editingMessage}}{{i18n
                    "disteleplus.editing"
                  }}{{else}}{{this.sender this.replyMessage}}{{/if}}</strong>
              {{#if this.replyMessage}}
                <em>{{this.safeCooked this.replyMessage.cooked}}</em>
              {{/if}}
            </span>
            <button
              type="button"
              title={{i18n "disteleplus.cancel"}}
              {{on "click" this.cancelContext}}
            >{{icon "xmark"}}</button>
          </div>
        {{/if}}

        {{#if this.uploads.length}}
          <div class="disteleplus-composer__uploads">
            {{#each this.uploads as |upload|}}
              <span>{{icon "paperclip"}}
                {{upload.original_filename}}<button
                  type="button"
                  title={{i18n "disteleplus.remove"}}
                  {{on "click" (fn this.removeUpload upload)}}
                >{{icon "xmark"}}</button></span>
            {{/each}}
          </div>
        {{/if}}

        <div class="disteleplus-composer__row">
          {{#if this.recordingVoice}}
            <DisteleplusVoiceRecorder
              @onClose={{this.closeVoiceRecorder}}
              @onSent={{this.voiceNoteSent}}
            />
          {{else}}
            <div
              class="disteleplus-composer__input
                {{if this.cannotSend 'is-send-disabled' 'is-send-enabled'}}"
            >
              <label
                class="disteleplus-composer__button"
                title={{i18n "disteleplus.attach"}}
              >
                {{icon "plus"}}
                <input type="file" multiple {{on "change" this.pickFiles}} />
              </label>
              <textarea
                value={{this.draft}}
                rows="1"
                maxlength="20000"
                placeholder={{i18n "disteleplus.placeholder"}}
                {{on "input" this.updateDraft}}
                {{on "keydown" this.composerKeydown}}
                {{on "paste" this.onPaste}}
                {{didInsert this.setupComposerTextarea}}
              ></textarea>
              {{#if this.voiceNotesEnabled}}
                <button
                  class="disteleplus-composer__button"
                  type="button"
                  title={{i18n "disteleplus.voice.button"}}
                  aria-label={{i18n "disteleplus.voice.button"}}
                  {{on "click" this.openVoiceRecorder}}
                >
                  {{icon "microphone"}}
                </button>
              {{/if}}
              <button
                class="disteleplus-composer__button"
                type="button"
                title={{i18n "disteleplus.emoji"}}
                aria-label={{i18n "disteleplus.emoji"}}
                {{on "click" this.insertEmoji}}
              >
                {{icon "face-smile"}}
              </button>
              <div class="disteleplus-composer__separator"></div>
              <button
                class="disteleplus-composer__button is-send"
                type="button"
                title={{i18n "disteleplus.send"}}
                aria-label={{i18n "disteleplus.send"}}
                disabled={{this.cannotSend}}
                {{on "click" this.send}}
              >
                {{#if (or this.disteleplus.sending this.uploading)}}
                  {{icon "spinner" class="fa-spin"}}
                {{else}}
                  {{icon "paper-plane"}}
                {{/if}}
              </button>
            </div>
          {{/if}}
        </div>
      </footer>
    </section>
  </template>
}
