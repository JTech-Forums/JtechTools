import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { or } from "truth-helpers";

// Moderator-facing modal (opened from the topic admin wrench menu) for
// setting this topic's pinned footer message, require-approval flag, and
// the private staff note. The per-topic before-reply prompt has moved
// out of this modal and into the dedicated "Prompt Checklist" entry,
// which supports both statement and checklist modes.
//
// Each section renders only while its feature toggle is on, and the PUT
// payload carries only the enabled fields — the server 404s any param whose
// toggle is off, so sending everything unconditionally used to break saving
// the remaining sections when one toggle was disabled.
export default class ModTopicMessagesModal extends Component {
  @service appEvents;
  @service siteSettings;
  @service toasts;

  @tracked footerMessage = this.topic.mod_topic_footer_message || "";
  @tracked requireApproval =
    this.topic.mod_topic_require_reply_approval || false;
  @tracked privateNote = this.topic.mod_topic_private_note || "";
  @tracked notePosition =
    this.topic.mod_topic_private_note_position || "bottom";
  @tracked saving = false;

  get topic() {
    return this.args.model.topic;
  }

  get footerEnabled() {
    return this.siteSettings.topic_footer_message_enabled;
  }

  get approvalEnabled() {
    return this.siteSettings.mod_topic_require_reply_approval_enabled;
  }

  get notesEnabled() {
    return this.siteSettings.mod_topic_private_notes_enabled;
  }

  @action
  updateFooter(event) {
    this.footerMessage = event.target.value;
  }

  @action
  toggleApproval(event) {
    this.requireApproval = event.target.checked;
  }

  @action
  updateNote(event) {
    this.privateNote = event.target.value;
  }

  @action
  updateNotePosition(event) {
    this.notePosition = event.target.value;
  }

  @action
  async save() {
    this.saving = true;

    try {
      const data = {};
      if (this.footerEnabled) {
        data.footer_message = this.footerMessage;
      }
      if (this.approvalEnabled) {
        data.require_reply_approval = this.requireApproval;
      }
      if (this.notesEnabled) {
        data.private_note = this.privateNote;
        data.private_note_position = this.notePosition;
      }

      const result = await ajax(
        `/discourse-mod-categories/topic/${this.topic.id}`,
        { type: "PUT", data }
      );

      if (this.footerEnabled) {
        this.topic.set("mod_topic_footer_message", result.footer_message);
      }
      if (this.approvalEnabled) {
        this.topic.set(
          "mod_topic_require_reply_approval",
          result.require_reply_approval
        );
      }
      if (this.notesEnabled) {
        this.topic.set("mod_topic_private_note", result.private_note);
        this.topic.set(
          "mod_topic_private_note_position",
          result.private_note_position
        );
        this.topic.set(
          "mod_topic_private_note_author",
          result.private_note_author
        );
      }
      this.appEvents.trigger("discourse-mod:messages-updated", this.topic);
      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n("discourse_mod_categories.topic_messages.saved_toast"),
        },
      });
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_mod_categories.topic_messages.title"}}
      @closeModal={{@closeModal}}
      class="mod-topic-messages-modal"
    >
      <:body>
        {{#if this.footerEnabled}}
          <h3 class="mod-messages-section">
            {{i18n "discourse_mod_categories.topic_messages.section_visible"}}
          </h3>
          <div class="control-group">
            <label class="mod-messages-label">
              {{i18n "discourse_mod_categories.topic_messages.footer_label"}}
            </label>
            <p class="mod-messages-hint">
              {{i18n "discourse_mod_categories.topic_messages.footer_hint"}}
            </p>
            <textarea
              class="mod-footer-input"
              rows="3"
              value={{this.footerMessage}}
              {{on "input" this.updateFooter}}
            ></textarea>
          </div>
        {{/if}}

        {{#if (or this.approvalEnabled this.notesEnabled)}}
          <h3 class="mod-messages-section">
            {{i18n
              "discourse_mod_categories.topic_messages.section_moderation"
            }}
          </h3>
        {{/if}}
        {{#if this.approvalEnabled}}
          <div class="control-group mod-approval-control">
            <label class="mod-approval-checkbox">
              <input
                type="checkbox"
                class="mod-require-approval-input"
                checked={{this.requireApproval}}
                {{on "change" this.toggleApproval}}
              />
              <span class="mod-messages-label">
                {{i18n
                  "discourse_mod_categories.topic_messages.approval_label"
                }}
              </span>
            </label>
            <p class="mod-messages-hint">
              {{i18n "discourse_mod_categories.topic_messages.approval_hint"}}
            </p>
          </div>
        {{/if}}

        {{#if this.notesEnabled}}
          <div class="control-group mod-private-note-control">
            <label class="mod-messages-label">
              {{i18n "discourse_mod_categories.topic_messages.note_label"}}
            </label>
            <p class="mod-messages-hint">
              {{i18n "discourse_mod_categories.topic_messages.note_hint"}}
            </p>
            <textarea
              class="mod-private-note-input"
              rows="3"
              value={{this.privateNote}}
              {{on "input" this.updateNote}}
            ></textarea>
            <label class="mod-messages-label">
              {{i18n
                "discourse_mod_categories.topic_messages.note_position_label"
              }}
            </label>
            <select
              class="mod-private-note-position-input"
              value={{this.notePosition}}
              {{on "change" this.updateNotePosition}}
            >
              <option value="bottom">
                {{i18n
                  "discourse_mod_categories.topic_messages.note_position_bottom"
                }}
              </option>
              <option value="top">
                {{i18n
                  "discourse_mod_categories.topic_messages.note_position_top"
                }}
              </option>
            </select>
          </div>
        {{/if}}
      </:body>

      <:footer>
        <DButton
          @action={{this.save}}
          @label="discourse_mod_categories.topic_messages.save"
          @disabled={{this.saving}}
          class="btn-primary mod-messages-save"
        />
        <DButton
          @action={{@closeModal}}
          @label="discourse_mod_categories.topic_messages.cancel"
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
