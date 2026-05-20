import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cook } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import ModTopicMessagesModal from "./mod-topic-messages-modal";

// Short relative-time label ("just now", "5m", "3h", "2d") for a note.
function timeAgo(iso) {
  if (!iso) {
    return "";
  }
  const then = new Date(iso).getTime();
  if (isNaN(then)) {
    return "";
  }
  const seconds = Math.max(0, (Date.now() - then) / 1000);
  if (seconds < 60) {
    return i18n("discourse_mod_categories.private_note.just_now");
  }
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return `${minutes}m`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours}h`;
  }
  return `${Math.floor(hours / 24)}d`;
}

function authorName(author) {
  return author ? author.name || author.username : null;
}

function avatarUrl(author) {
  const template = author?.avatar_template;
  return template ? template.replace("{size}", "45") : null;
}

// A staff-only note on a topic — and its thread of staff replies. Shown
// like posts (avatar, name, relative time). The note is serialized only
// to staff; this component also renders nothing unless the current user
// is staff. `@place` is "top" or "bottom".
//
// Staff can edit and delete individual entries — each reply, and the
// note body itself. The hosting plugin-outlet connector is reused across
// topic navigation, so all per-topic tracked state is re-read whenever
// `@topic.id` changes (via a `{{did-update}}` modifier).
export default class ModPrivateNote extends Component {
  @service appEvents;
  @service currentUser;
  @service dialog;
  @service modal;

  @tracked note = this.args.topic?.mod_topic_private_note || "";
  @tracked position =
    this.args.topic?.mod_topic_private_note_position || "bottom";
  @tracked author = this.args.topic?.mod_topic_private_note_author || null;
  @tracked createdAt =
    this.args.topic?.mod_topic_private_note_created_at || null;
  @tracked replies = this.args.topic?.mod_topic_private_note_replies || [];
  @tracked replying = false;
  @tracked replyText = "";
  @tracked saving = false;
  @tracked cookedNote = null;
  @tracked cookedReplies = [];
  // The id of the reply currently being edited inline, or null.
  @tracked editingReplyId = null;
  @tracked editText = "";

  constructor() {
    super(...arguments);
    this.appEvents.on("discourse-mod:messages-updated", this, this.refresh);
    this.cookContent();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("discourse-mod:messages-updated", this, this.refresh);
  }

  // appEvent handler for live edits within the current topic. The guard
  // keeps a stale event for another topic from clobbering this one.
  refresh(topic) {
    if (!topic || topic.id !== this.args.topic?.id) {
      return;
    }
    this.readTopicState(topic);
  }

  // Re-read all per-topic state from the current topic. Called on initial
  // insert and whenever the connector is reused for a different topic.
  @action
  refreshOnNavigation() {
    this.readTopicState(this.args.topic);
  }

  readTopicState(topic) {
    this.note = topic?.mod_topic_private_note || "";
    this.position = topic?.mod_topic_private_note_position || "bottom";
    this.author = topic?.mod_topic_private_note_author || null;
    this.createdAt = topic?.mod_topic_private_note_created_at || null;
    this.replies = topic?.mod_topic_private_note_replies || [];
    this.replying = false;
    this.replyText = "";
    this.editingReplyId = null;
    this.editText = "";
    this.cookContent();
  }

  // Cooks the raw note markdown and each reply body asynchronously. The
  // stored/edited values stay raw — only the display is cooked.
  async cookContent() {
    const note = this.note;
    if (note && note.trim().length > 0) {
      const cooked = await cook(note);
      if (this.note === note) {
        this.cookedNote = cooked;
      }
    } else {
      this.cookedNote = null;
    }

    const replies = this.replies || [];
    const cooked = await Promise.all(
      replies.map((reply) => cook(reply.raw || ""))
    );
    if (this.replies === replies) {
      this.cookedReplies = cooked;
    }
  }

  get visible() {
    if (!this.currentUser?.staff) {
      return false;
    }
    if (!this.note || this.note.trim().length === 0) {
      return false;
    }
    const place = this.args.place === "top" ? "top" : "bottom";
    const chosen = this.position === "top" ? "top" : "bottom";
    return place === chosen;
  }

  get noteHtml() {
    return this.cookedNote;
  }

  get authorName() {
    return authorName(this.author);
  }

  get avatarUrl() {
    return avatarUrl(this.author);
  }

  get createdAgo() {
    return timeAgo(this.createdAt);
  }

  get decoratedReplies() {
    return (this.replies || []).map((reply, index) => ({
      id: reply.id,
      raw: reply.raw,
      cooked: this.cookedReplies[index] || null,
      agoLabel: timeAgo(reply.created_at),
      authorName: authorName(reply.author),
      avatarUrl: avatarUrl(reply.author),
      editing: this.editingReplyId === reply.id,
    }));
  }

  // Applies a note-thread response (note body + replies) to local state.
  applyThread(result) {
    if (result.private_note !== undefined) {
      this.note = result.private_note || "";
      this.args.topic.set("mod_topic_private_note", this.note);
    }
    if (result.private_note_author !== undefined) {
      this.author = result.private_note_author || null;
      this.args.topic.set(
        "mod_topic_private_note_author",
        result.private_note_author || null
      );
    }
    if (result.private_note_created_at !== undefined) {
      this.createdAt = result.private_note_created_at || null;
      this.args.topic.set(
        "mod_topic_private_note_created_at",
        result.private_note_created_at || null
      );
    }
    this.replies = result.replies || [];
    this.args.topic.set("mod_topic_private_note_replies", this.replies);
    this.cookContent();
    this.appEvents.trigger("discourse-mod:messages-updated", this.args.topic);
  }

  @action
  toggleReply() {
    this.replying = !this.replying;
  }

  @action
  updateReplyText(event) {
    this.replyText = event.target.value;
  }

  @action
  async submitReply() {
    const raw = this.replyText.trim();
    if (!raw) {
      return;
    }
    this.saving = true;

    try {
      const result = await ajax(
        `/discourse-mod-categories/topic/${this.args.topic.id}/note-reply`,
        { type: "POST", data: { raw } }
      );
      this.replies = result.replies || [];
      this.args.topic.set("mod_topic_private_note_replies", this.replies);
      this.cookContent();
      this.replyText = "";
      this.replying = false;
      this.appEvents.trigger("discourse-mod:messages-updated", this.args.topic);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  // ----- per-reply edit / delete -----

  @action
  startEditReply(reply) {
    this.editingReplyId = reply.id;
    this.editText = reply.raw || "";
  }

  @action
  cancelEditReply() {
    this.editingReplyId = null;
    this.editText = "";
  }

  @action
  updateEditText(event) {
    this.editText = event.target.value;
  }

  @action
  async saveEditReply() {
    const raw = this.editText.trim();
    const replyId = this.editingReplyId;
    if (!raw || !replyId) {
      return;
    }
    this.saving = true;

    try {
      const result = await ajax(
        `/discourse-mod-categories/topic/${this.args.topic.id}/note-reply`,
        { type: "PUT", data: { reply_id: replyId, raw } }
      );
      this.applyThread(result);
      this.editingReplyId = null;
      this.editText = "";
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  deleteReply(reply) {
    this.dialog.confirm({
      message: i18n(
        "discourse_mod_categories.private_note.delete_reply_confirm"
      ),
      didConfirm: async () => {
        this.saving = true;
        try {
          const result = await ajax(
            `/discourse-mod-categories/topic/${this.args.topic.id}/note-reply`,
            { type: "DELETE", data: { reply_id: reply.id } }
          );
          this.applyThread(result);
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.saving = false;
        }
      },
    });
  }

  // ----- note-body edit / delete -----

  @action
  editNote() {
    this.modal.show(ModTopicMessagesModal, {
      model: { topic: this.args.topic },
    });
  }

  @action
  deleteNote() {
    this.dialog.confirm({
      message: i18n(
        "discourse_mod_categories.private_note.delete_note_confirm"
      ),
      didConfirm: async () => {
        this.saving = true;
        try {
          const result = await ajax(
            `/discourse-mod-categories/topic/${this.args.topic.id}/note`,
            { type: "DELETE" }
          );
          this.applyThread(result);
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.saving = false;
        }
      },
    });
  }

  <template>
    <div
      class="mod-private-note-outlet"
      {{didInsert this.refreshOnNavigation}}
      {{didUpdate this.refreshOnNavigation @topic.id}}
    >
      {{#if this.visible}}
        <div class="mod-private-note">
          <div class="mod-private-note-marker">
            {{icon "lock"}}
            <span>{{i18n
                "discourse_mod_categories.private_note.heading"
              }}</span>
          </div>

          <article class="mod-private-note-post">
            {{#if this.avatarUrl}}
              <img
                class="mod-private-note-avatar"
                src={{this.avatarUrl}}
                width="45"
                height="45"
                alt=""
              />
            {{/if}}
            <div class="mod-private-note-main">
              <div class="mod-private-note-byline">
                {{#if this.authorName}}
                  <span class="mod-private-note-username">
                    {{this.authorName}}
                  </span>
                {{/if}}
                {{#if this.createdAgo}}
                  <span class="mod-private-note-time">{{this.createdAgo}}</span>
                {{/if}}
                <span class="mod-private-note-controls">
                  <DButton
                    @action={{this.editNote}}
                    @icon="pencil"
                    @title="discourse_mod_categories.private_note.edit_note"
                    class="btn-flat btn-small mod-private-note-edit-note"
                  />
                  <DButton
                    @action={{this.deleteNote}}
                    @icon="trash-can"
                    @title="discourse_mod_categories.private_note.delete_note"
                    class="btn-flat btn-small mod-private-note-delete-note"
                  />
                </span>
              </div>
              <div class="cooked">{{this.noteHtml}}</div>
            </div>
          </article>

          {{#each this.decoratedReplies as |reply|}}
            <article class="mod-private-note-post mod-private-note-reply">
              {{#if reply.avatarUrl}}
                <img
                  class="mod-private-note-avatar"
                  src={{reply.avatarUrl}}
                  width="45"
                  height="45"
                  alt=""
                />
              {{/if}}
              <div class="mod-private-note-main">
                <div class="mod-private-note-byline">
                  {{#if reply.authorName}}
                    <span class="mod-private-note-username">
                      {{reply.authorName}}
                    </span>
                  {{/if}}
                  {{#if reply.agoLabel}}
                    <span
                      class="mod-private-note-time"
                    >{{reply.agoLabel}}</span>
                  {{/if}}
                  {{#unless reply.editing}}
                    <span class="mod-private-note-controls">
                      <DButton
                        @action={{fn this.startEditReply reply}}
                        @icon="pencil"
                        @title="discourse_mod_categories.private_note.edit_reply"
                        class="btn-flat btn-small mod-private-note-edit-reply"
                      />
                      <DButton
                        @action={{fn this.deleteReply reply}}
                        @icon="trash-can"
                        @title="discourse_mod_categories.private_note.delete_reply"
                        class="btn-flat btn-small mod-private-note-delete-reply"
                      />
                    </span>
                  {{/unless}}
                </div>
                {{#if reply.editing}}
                  <div class="mod-private-note-reply-box">
                    <textarea
                      class="mod-private-note-edit-input"
                      rows="2"
                      value={{this.editText}}
                      {{on "input" this.updateEditText}}
                    ></textarea>
                    <div class="mod-private-note-reply-actions">
                      <DButton
                        @action={{this.saveEditReply}}
                        @label="discourse_mod_categories.private_note.save"
                        @disabled={{this.saving}}
                        class="btn-primary btn-small"
                      />
                      <DButton
                        @action={{this.cancelEditReply}}
                        @label="discourse_mod_categories.private_note.cancel"
                        class="btn-flat btn-small"
                      />
                    </div>
                  </div>
                {{else}}
                  <div
                    class="mod-private-note-reply-text cooked"
                  >{{reply.cooked}}</div>
                {{/if}}
              </div>
            </article>
          {{/each}}

          {{#if this.replying}}
            <div class="mod-private-note-reply-box">
              <textarea
                class="mod-private-note-reply-input"
                rows="2"
                placeholder={{i18n
                  "discourse_mod_categories.private_note.reply_placeholder"
                }}
                value={{this.replyText}}
                {{on "input" this.updateReplyText}}
              ></textarea>
              <div class="mod-private-note-reply-actions">
                <DButton
                  @action={{this.submitReply}}
                  @label="discourse_mod_categories.private_note.add_reply"
                  @disabled={{this.saving}}
                  class="btn-primary btn-small"
                />
                <DButton
                  @action={{this.toggleReply}}
                  @label="discourse_mod_categories.private_note.cancel"
                  class="btn-flat btn-small"
                />
              </div>
            </div>
          {{else}}
            <DButton
              @action={{this.toggleReply}}
              @icon="reply"
              @label="discourse_mod_categories.private_note.reply"
              class="btn-flat btn-small mod-private-note-reply-button"
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
