import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import { trustLevelOptions } from "../lib/trust-level-options";

// One editable row in the per-topic prompt checklist. Tracked so editing
// the label/url in place re-renders without rebuilding the whole list.
class ChecklistRow {
  @tracked label;
  @tracked url;

  constructor(label = "", url = "") {
    this.label = label;
    this.url = url;
  }
}

// Staff-facing modal opened from the topic admin (wrench) menu's
// "Prompt Checklist" entry. Lets a moderator add/edit/save the per-topic
// prompt. Mode picks between a single-message Statement and a multi-item
// Checklist; frequency picks between "once per user per topic" and "on
// every reply"; max_tl caps the audience by trust level. Saving bumps
// the version, re-prompting any user who already accepted an older one.
export default class ModTopicPromptChecklistModal extends Component {
  @service toasts;

  @tracked rows = [];
  @tracked version = 0;
  @tracked buttonLabel = "";
  @tracked updatedAt = null;
  @tracked mode = "checklist";
  @tracked statement = "";
  @tracked frequency = "once";
  @tracked maxTl = "4";
  @tracked fromLegacy = false;
  @tracked loading = true;
  @tracked saving = false;

  modeOptions = [
    {
      id: "statement",
      name: i18n("discourse_mod_categories.topic_prompt_checklist.mode_statement"),
    },
    {
      id: "checklist",
      name: i18n("discourse_mod_categories.topic_prompt_checklist.mode_checklist"),
    },
  ];

  frequencyOptions = [
    {
      id: "once",
      name: i18n("discourse_mod_categories.topic_prompt_checklist.frequency_once"),
    },
    {
      id: "every_reply",
      name: i18n(
        "discourse_mod_categories.topic_prompt_checklist.frequency_every_reply"
      ),
    },
  ];

  maxTlOptions = trustLevelOptions(true);

  constructor() {
    super(...arguments);
    this.load();
  }

  get topic() {
    return this.args.model.topic;
  }

  get lastRowIndex() {
    return this.rows.length - 1;
  }

  get isStatementMode() {
    return this.mode === "statement";
  }

  get isChecklistMode() {
    return this.mode === "checklist";
  }

  async load() {
    try {
      const result = await ajax(
        `/discourse-mod-categories/topic/${this.topic.id}/prompt-checklist.json`
      );
      this.rows = (result.items || []).map(
        (item) => new ChecklistRow(item.label, item.url)
      );
      this.version = result.version || 0;
      this.buttonLabel = result.button_label || "";
      this.updatedAt = result.updated_at;
      this.mode = result.mode === "statement" ? "statement" : "checklist";
      this.statement = result.statement || "";
      this.frequency =
        result.frequency === "every_reply" ? "every_reply" : "once";
      this.maxTl = String(result.max_tl ?? 4);
      this.fromLegacy = !!result.from_legacy;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  addRow() {
    this.rows = [...this.rows, new ChecklistRow()];
  }

  @action
  removeRow(row) {
    this.rows = this.rows.filter((r) => r !== row);
  }

  @action
  updateLabel(row, event) {
    row.label = event.target.value;
  }

  @action
  updateUrl(row, event) {
    row.url = event.target.value;
  }

  @action
  updateButtonLabel(event) {
    this.buttonLabel = event.target.value;
  }

  @action
  updateStatement(event) {
    this.statement = event.target.value;
  }

  @action
  updateMode(value) {
    this.mode = value;
  }

  @action
  updateFrequency(value) {
    this.frequency = value;
  }

  @action
  updateMaxTl(value) {
    this.maxTl = value;
  }

  @action
  async save() {
    this.saving = true;
    try {
      const result = await ajax(
        `/discourse-mod-categories/topic/${this.topic.id}/prompt-checklist.json`,
        {
          type: "PUT",
          data: {
            mode: this.mode,
            statement: this.statement,
            items: this.rows.map((r) => ({ label: r.label, url: r.url })),
            frequency: this.frequency,
            max_tl: this.maxTl,
            button_label: this.buttonLabel,
          },
        }
      );
      this.version = result.version || 0;
      this.rows = (result.items || []).map(
        (item) => new ChecklistRow(item.label, item.url)
      );
      this.buttonLabel = result.button_label || "";
      this.updatedAt = result.updated_at;
      this.mode = result.mode === "statement" ? "statement" : "checklist";
      this.statement = result.statement || "";
      this.frequency =
        result.frequency === "every_reply" ? "every_reply" : "once";
      this.maxTl = String(result.max_tl ?? 4);
      this.fromLegacy = false;
      this.topic.set("mod_topic_prompt_checklist", {
        version: this.version,
        mode: this.mode,
        statement: this.statement,
        items: result.items || [],
        frequency: this.frequency,
        max_tl: parseInt(this.maxTl, 10) || 4,
        button_label: this.buttonLabel,
        updated_at: this.updatedAt,
      });
      // The new config supersedes the legacy reply-prompt fields, which
      // the server has cleared. Reflect that on the in-memory topic too
      // so the (now-removed) legacy gate stops reading stale data.
      this.topic.set("mod_topic_reply_prompt", null);
      this.topic.set("mod_topic_reply_prompt_max_tl", null);
      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n(
            "discourse_mod_categories.topic_prompt_checklist.saved_toast"
          ),
        },
      });
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  async clear() {
    this.saving = true;
    try {
      await ajax(
        `/discourse-mod-categories/topic/${this.topic.id}/prompt-checklist.json`,
        { type: "DELETE" }
      );
      this.rows = [];
      this.version = 0;
      this.buttonLabel = "";
      this.updatedAt = null;
      this.mode = "checklist";
      this.statement = "";
      this.frequency = "once";
      this.maxTl = "4";
      this.fromLegacy = false;
      this.topic.set("mod_topic_prompt_checklist", null);
      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n(
            "discourse_mod_categories.topic_prompt_checklist.cleared_toast"
          ),
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
      @title={{i18n "discourse_mod_categories.topic_prompt_checklist.title"}}
      @closeModal={{@closeModal}}
      class="mod-topic-prompt-checklist-modal"
    >
      <:body>
        <p class="mod-topic-prompt-checklist-intro">
          {{i18n "discourse_mod_categories.topic_prompt_checklist.intro"}}
        </p>

        {{#if this.loading}}
          <p class="mod-topic-prompt-checklist-loading">
            {{i18n
              "discourse_mod_categories.topic_prompt_checklist.loading"
            }}
          </p>
        {{else}}
          {{#if this.fromLegacy}}
            <div class="mod-topic-prompt-checklist-legacy-notice">
              {{i18n
                "discourse_mod_categories.topic_prompt_checklist.legacy_migration_notice"
              }}
            </div>
          {{/if}}

          {{#if this.version}}
            <p class="mod-checklist-version">
              {{i18n
                "discourse_mod_categories.topic_prompt_checklist.current_version"
                count=this.version
              }}
            </p>
          {{/if}}

          <div class="mod-checklist-field">
            <label class="mod-checklist-field-label">
              {{i18n
                "discourse_mod_categories.topic_prompt_checklist.mode_label"
              }}
            </label>
            <ComboBox
              @value={{this.mode}}
              @content={{this.modeOptions}}
              @onChange={{this.updateMode}}
              class="mod-topic-prompt-checklist-mode"
            />
          </div>

          {{#if this.isStatementMode}}
            <div class="mod-checklist-field">
              <label class="mod-checklist-field-label">
                {{i18n
                  "discourse_mod_categories.topic_prompt_checklist.statement_label"
                }}
              </label>
              <textarea
                class="mod-topic-prompt-checklist-statement"
                rows="4"
                placeholder={{i18n
                  "discourse_mod_categories.topic_prompt_checklist.statement_placeholder"
                }}
                value={{this.statement}}
                {{on "input" this.updateStatement}}
              ></textarea>
            </div>
          {{else}}
            {{#unless this.rows.length}}
              <div class="mod-topic-prompt-checklist-inactive">
                {{i18n
                  "discourse_mod_categories.topic_prompt_checklist.inactive"
                }}
              </div>
            {{/unless}}

            {{#if this.rows.length}}
              <div class="mod-checklist-rows">
                {{#each this.rows as |row|}}
                  <div class="mod-checklist-row">
                    <input
                      type="text"
                      class="mod-checklist-row-label"
                      placeholder={{i18n
                        "discourse_mod_categories.topic_prompt_checklist.item_label"
                      }}
                      value={{row.label}}
                      {{on "input" (fn this.updateLabel row)}}
                    />
                    <input
                      type="text"
                      class="mod-checklist-row-url"
                      placeholder={{i18n
                        "discourse_mod_categories.topic_prompt_checklist.item_url"
                      }}
                      value={{row.url}}
                      {{on "input" (fn this.updateUrl row)}}
                    />
                    <DButton
                      @action={{fn this.removeRow row}}
                      @icon="trash-can"
                      @title="discourse_mod_categories.topic_prompt_checklist.remove_item"
                      class="btn-flat mod-checklist-remove"
                    />
                  </div>
                {{/each}}
              </div>
            {{/if}}
          {{/if}}

          <div class="mod-checklist-field">
            <label class="mod-checklist-field-label">
              {{i18n
                "discourse_mod_categories.topic_prompt_checklist.frequency_label"
              }}
            </label>
            <ComboBox
              @value={{this.frequency}}
              @content={{this.frequencyOptions}}
              @onChange={{this.updateFrequency}}
              class="mod-topic-prompt-checklist-frequency"
            />
          </div>

          <div class="mod-checklist-field">
            <label class="mod-checklist-field-label">
              {{i18n
                "discourse_mod_categories.topic_prompt_checklist.max_tl_label"
              }}
            </label>
            <ComboBox
              @value={{this.maxTl}}
              @content={{this.maxTlOptions}}
              @onChange={{this.updateMaxTl}}
              class="mod-topic-prompt-checklist-max-tl"
            />
          </div>

          <div class="mod-checklist-field">
            <label class="mod-checklist-field-label">
              {{i18n
                "discourse_mod_categories.topic_prompt_checklist.button_label_label"
              }}
            </label>
            <input
              type="text"
              class="mod-topic-prompt-checklist-button-label"
              placeholder={{i18n
                "discourse_mod_categories.topic_prompt_checklist.button_label_placeholder"
              }}
              value={{this.buttonLabel}}
              {{on "input" this.updateButtonLabel}}
            />
          </div>
        {{/if}}
      </:body>

      <:footer>
        {{#if this.isChecklistMode}}
          <DButton
            @action={{this.addRow}}
            @icon="plus"
            @label="discourse_mod_categories.topic_prompt_checklist.add_item"
            class="mod-topic-prompt-checklist-add"
          />
        {{/if}}
        <DButton
          @action={{this.save}}
          @label="discourse_mod_categories.topic_prompt_checklist.save"
          @disabled={{this.saving}}
          class="btn-primary mod-topic-prompt-checklist-save"
        />
        {{#if this.version}}
          <DButton
            @action={{this.clear}}
            @icon="trash-can"
            @label="discourse_mod_categories.topic_prompt_checklist.clear"
            @disabled={{this.saving}}
            class="btn-danger mod-topic-prompt-checklist-clear"
          />
        {{/if}}
        <DButton
          @action={{@closeModal}}
          @label="discourse_mod_categories.topic_prompt_checklist.cancel"
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
