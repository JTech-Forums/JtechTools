import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { emojiSearch } from "pretty-text/emoji";
import { eq, or } from "truth-helpers";
import EmojiAutocompleteResults from "discourse/components/emoji-autocomplete-results";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import UserAutocompleteResults from "discourse/components/user-autocomplete-results";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getAbsoluteURL } from "discourse/lib/get-url";
import lightbox from "discourse/lib/lightbox";
import { emojiUrlFor } from "discourse/lib/text";
import userSearch from "discourse/lib/user-search";
import dAutocomplete from "discourse/ui-kit/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";
import { enhanceWithin } from "../lib/disteleplus-voice-player";
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
  @service dialog;
  @service modal;
  @service menu;
  @service emojiStore;
  @service composer;
  @service siteSettings;

  @tracked uploads = [];
  @tracked uploading = false;
  @tracked replyMessage = null;
  @tracked editingMessage = null;
  @tracked newBelow = 0;
  @tracked showJump = false;
  @tracked dragging = false;
  // { message, x, y } while a context menu is open.
  @tracked contextMenu = null;

  element = null;
  timeline = null;
  textarea = null;
  unsubscribe = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.unsubscribe?.();
    document.removeEventListener("click", this.closeContextMenu);
    document.removeEventListener("keydown", this.onDocumentKeydown);
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

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @action
  mount(element) {
    this.element = element;
    this.timeline = element.querySelector(".disteleplus-timeline");
    this.textarea = element.querySelector(".disteleplus-composer textarea");
    this.disteleplus.setViewing(true);
    this.unsubscribe = this.disteleplus.onNewMessage(this.onNewMessage);
    document.addEventListener("click", this.closeContextMenu);
    document.addEventListener("keydown", this.onDocumentKeydown);
    requestAnimationFrame(() => {
      this.openAtStart();
      this.enhance(element);
    });
  }

  // Deep link (#m123) wins; otherwise land on the unread divider like
  // Telegram does; otherwise the bottom.
  openAtStart() {
    const match = window.location.hash.match(/^#m(\d+)$/);
    if (match) {
      const target = this.messageElement(Number(match[1]));
      if (target) {
        this.highlight(target);
        this.showJump = !this.nearBottom;
        return;
      }
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

  enhance(root) {
    enhanceWithin(root, { allAudio: true });
    try {
      lightbox(root, this.siteSettings);
    } catch {
      // Lightbox is progressive enhancement; plain links still work.
    }
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
  }

  autosize(textarea) {
    textarea.style.height = "auto";
    textarea.style.height = `${Math.min(textarea.scrollHeight, 200)}px`;
  }

  @action
  composerKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      // Let an open autocomplete menu take the Enter key.
      if (document.querySelector(".autocomplete.d-autocomplete")) {
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

  // Autocomplete — same data sources core's composer uses.
  get mentionAutocomplete() {
    return {
      key: "@",
      component: UserAutocompleteResults,
      dataSource: (term) =>
        userSearch({ term, includeGroups: true, allowedUsers: false }),
      transformComplete: (result) => result.username || result.name,
      afterComplete: (value) => this.disteleplus.setDraft(value),
    };
  }

  get emojiAutocomplete() {
    return {
      key: ":",
      component: EmojiAutocompleteResults,
      transformComplete: (result) => `${result.code}:`,
      afterComplete: (value) => this.disteleplus.setDraft(value),
      triggerRule: async (textarea) =>
        !textarea.value.slice(0, textarea.selectionStart).match(/:\w*$/) ||
        true,
      dataSource: (term) => {
        if (term.length < 2) {
          return [];
        }
        return emojiSearch(term, {
          maxResults: 6,
          diversity: this.emojiStore?.diversity,
        }).map((code) => ({ code, src: emojiUrlFor(code) }));
      },
    };
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
    this.uploads = this.uploads.filter(
      (candidate) => candidate.id !== upload.id
    );
  }

  @action
  openVoiceRecorder() {
    this.modal.show(DisteleplusVoiceRecorder, { model: { native: true } });
  }

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
  scrollToBottom() {
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
    const target = this.messageElement(message.id);
    if (target) {
      this.highlight(target);
    }
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

  <template>
    <section
      class="disteleplus-page {{if this.dragging 'is-dragging'}}"
      {{didInsert this.mount}}
      {{on "dragover" this.onDragOver}}
      {{on "dragleave" this.onDragLeave}}
      {{on "drop" this.onDrop}}
    >
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
              >
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
                        {{else if message.reply_to.cooked}}
                          <span>{{this.safeCooked
                              message.reply_to.cooked
                            }}</span>
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
                      <div class="disteleplus-uploads">
                        {{#each message.uploads as |upload|}}
                          {{#if (eq upload.kind "image")}}
                            <a
                              href={{upload.url}}
                              class="disteleplus-upload is-image lightbox"
                              data-download-href={{upload.url}}
                              title={{upload.original_filename}}
                            >
                              <img
                                src={{upload.url}}
                                alt={{upload.original_filename}}
                                width={{upload.width}}
                                height={{upload.height}}
                                loading="lazy"
                              />
                            </a>
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
          <div class="disteleplus-composer__input">
            <label
              class="disteleplus-composer__tool"
              title={{i18n "disteleplus.attach"}}
            >
              {{icon "paperclip"}}
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
              {{dAutocomplete this.mentionAutocomplete}}
              {{dAutocomplete this.emojiAutocomplete}}
            ></textarea>
            <button
              class="disteleplus-composer__tool"
              type="button"
              title={{i18n "disteleplus.emoji"}}
              {{on "click" this.insertEmoji}}
            >
              {{icon "face-smile"}}
            </button>
          </div>
          {{#if this.cannotSend}}
            <button
              class="disteleplus-composer__main"
              type="button"
              title={{i18n "disteleplus.voice.button"}}
              aria-label={{i18n "disteleplus.voice.button"}}
              disabled={{or this.disteleplus.sending this.uploading}}
              {{on "click" this.openVoiceRecorder}}
            >
              {{#if (or this.disteleplus.sending this.uploading)}}
                {{icon "spinner" class="fa-spin"}}
              {{else}}
                {{icon "microphone"}}
              {{/if}}
            </button>
          {{else}}
            <button
              class="disteleplus-composer__main is-send"
              type="button"
              title={{i18n "disteleplus.send"}}
              aria-label={{i18n "disteleplus.send"}}
              {{on "click" this.send}}
            >
              {{icon "paper-plane"}}
            </button>
          {{/if}}
        </div>
      </footer>
    </section>
  </template>
}
