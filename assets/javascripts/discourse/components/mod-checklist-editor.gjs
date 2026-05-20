import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import { trustLevelOptions } from "../lib/trust-level-options";

// One editable checklist row. Tracked so editing the label/url in place
// re-renders without rebuilding the whole list.
class ChecklistRow {
  @tracked label;
  @tracked url;

  constructor(label = "", url = "") {
    this.label = label;
    this.url = url;
  }
}

// One editable targeted checklist: its own name, target users, item rows,
// accept-button text and (server-owned) version. Tracked so in-place edits
// re-render without rebuilding the section.
class TargetedChecklist {
  @tracked name;
  @tracked usernames;
  @tracked rows;
  @tracked buttonLabel;
  @tracked version;

  constructor(data = {}) {
    this.id = data.id || null;
    this.name = data.name || "";
    this.usernames = (data.users || []).map((u) => u.username);
    this.rows = (data.items || []).map(
      (item) => new ChecklistRow(item.label, item.url)
    );
    this.buttonLabel = data.button_label || "";
    this.version = data.version || 0;
  }
}

// The first-post checklist editor (shown in the /mod-checklist modal).
// Staff add, edit, remove, and save the list of items; saving bumps the
// version so every user who already accepted is prompted again. The
// editor also manages targeted checklists and per-user re-accept resets.
export default class ModChecklistEditor extends Component {
  @service toasts;

  audienceOptions = trustLevelOptions(false);

  @tracked rows = (this.args.data.items || []).map(
    (item) => new ChecklistRow(item.label, item.url)
  );
  @tracked version = this.args.data.version || 0;
  @tracked maxTl = String(this.args.data.max_tl ?? 2);
  @tracked buttonLabel = this.args.data.button_label || "";
  @tracked saving = false;
  @tracked saved = false;
  @tracked onlyCurrentVersion = false;
  @tracked logEntries = this.args.data.log || [];
  @tracked targeted = (this.args.data.targeted || []).map(
    (t) => new TargetedChecklist(t)
  );

  // Index of the last checklist row, used to disable the down button.
  get lastRowIndex() {
    return this.rows.length - 1;
  }

  // The acceptance audit log, newest first, with the ISO timestamp parsed
  // to a Date for relative-time display. Refreshed in place after a
  // require-re-accept reset.
  get log() {
    return this.logEntries.map((entry) => ({
      ...entry,
      at: entry.accepted_at ? new Date(entry.accepted_at) : null,
    }));
  }

  // The log narrowed to the current checklist version when the staff
  // member ticks "current version only".
  get filteredLog() {
    if (!this.onlyCurrentVersion) {
      return this.log;
    }
    return this.log.filter((entry) => entry.version === this.version);
  }

  @action
  toggleLogFilter(event) {
    this.onlyCurrentVersion = event.target.checked;
  }

  @action
  addRow() {
    this.rows = [...this.rows, new ChecklistRow()];
    this.saved = false;
  }

  @action
  removeRow(row) {
    this.rows = this.rows.filter((r) => r !== row);
    this.saved = false;
  }

  // Swap a row with the one before/after it. Reassigning this.rows
  // re-renders the list; like addRow/removeRow it marks the editor unsaved.
  moveRow(row, delta) {
    const index = this.rows.indexOf(row);
    const target = index + delta;
    if (index === -1 || target < 0 || target >= this.rows.length) {
      return;
    }
    const next = [...this.rows];
    next[index] = next[target];
    next[target] = row;
    this.rows = next;
    this.saved = false;
  }

  @action
  moveRowUp(row) {
    this.moveRow(row, -1);
  }

  @action
  moveRowDown(row) {
    this.moveRow(row, 1);
  }

  @action
  updateLabel(row, event) {
    row.label = event.target.value;
    this.saved = false;
  }

  @action
  updateUrl(row, event) {
    row.url = event.target.value;
    this.saved = false;
  }

  @action
  updateMaxTl(value) {
    this.maxTl = value;
    this.saved = false;
  }

  @action
  updateButtonLabel(event) {
    this.buttonLabel = event.target.value;
    this.saved = false;
  }

  // --- Require re-accept ----------------------------------------------

  // Reset one logged user so the forum-wide checklist is shown again on
  // their next post, then refresh the log from the server response.
  @action
  async requireReaccept(entry) {
    try {
      const result = await ajax(
        "/discourse-mod-categories/checklist/require-reaccept",
        { type: "POST", data: { username: entry.username } }
      );
      if (result.log) {
        this.logEntries = result.log;
      }
      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n(
            "discourse_mod_categories.first_post_checklist.reaccept_done",
            { username: entry.username }
          ),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  // --- Targeted checklists --------------------------------------------

  @action
  addTargeted() {
    this.targeted = [...this.targeted, new TargetedChecklist()];
  }

  @action
  updateTargetedName(checklist, event) {
    checklist.name = event.target.value;
  }

  @action
  updateTargetedUsers(checklist, usernames) {
    checklist.usernames = usernames;
  }

  @action
  updateTargetedButtonLabel(checklist, event) {
    checklist.buttonLabel = event.target.value;
  }

  @action
  addTargetedRow(checklist) {
    checklist.rows = [...checklist.rows, new ChecklistRow()];
  }

  @action
  removeTargetedRow(checklist, row) {
    checklist.rows = checklist.rows.filter((r) => r !== row);
  }

  @action
  updateTargetedLabel(row, event) {
    row.label = event.target.value;
  }

  @action
  updateTargetedUrl(row, event) {
    row.url = event.target.value;
  }

  // Create or update a targeted checklist, then replace the section's
  // state with the server's canonical list (ids, bumped versions).
  @action
  async saveTargeted(checklist) {
    this.saving = true;
    const data = {
      name: checklist.name,
      user_ids: checklist.usernames,
      button_label: checklist.buttonLabel,
      items: checklist.rows.map((r) => ({ label: r.label, url: r.url })),
    };
    try {
      const result = checklist.id
        ? await ajax(
            `/discourse-mod-categories/checklist/targeted/${checklist.id}`,
            { type: "PUT", data }
          )
        : await ajax("/discourse-mod-categories/checklist/targeted", {
            type: "POST",
            data,
          });
      this.targeted = (result.targeted || []).map(
        (t) => new TargetedChecklist(t)
      );
      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n(
            "discourse_mod_categories.first_post_checklist.targeted_saved"
          ),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  async deleteTargeted(checklist) {
    // An unsaved (id-less) checklist is just dropped client-side.
    if (!checklist.id) {
      this.targeted = this.targeted.filter((c) => c !== checklist);
      return;
    }
    try {
      const result = await ajax(
        `/discourse-mod-categories/checklist/targeted/${checklist.id}`,
        { type: "DELETE" }
      );
      this.targeted = (result.targeted || []).map(
        (t) => new TargetedChecklist(t)
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async save() {
    this.saving = true;

    try {
      const result = await ajax("/discourse-mod-categories/checklist", {
        type: "PUT",
        data: {
          items: this.rows.map((r) => ({ label: r.label, url: r.url })),
          max_tl: this.maxTl,
          button_label: this.buttonLabel,
        },
      });
      this.version = result.version;
      this.maxTl = String(result.max_tl ?? 2);
      this.buttonLabel = result.button_label || "";
      this.rows = (result.items || []).map(
        (item) => new ChecklistRow(item.label, item.url)
      );
      this.saved = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <div class="mod-checklist-page">
      {{#if this.version}}
        <p class="mod-checklist-version">
          {{i18n
            "discourse_mod_categories.first_post_checklist.current_version"
            count=this.version
          }}
        </p>
      {{/if}}
      <p class="mod-checklist-editor-intro">
        {{i18n "discourse_mod_categories.first_post_checklist.editor_intro"}}
      </p>

      {{#unless this.rows.length}}
        <div class="mod-checklist-inactive">
          {{i18n "discourse_mod_categories.first_post_checklist.inactive"}}
        </div>
      {{/unless}}

      {{#if this.rows.length}}
        <div class="mod-checklist-rows">
          {{#each this.rows as |row index|}}
            <div class="mod-checklist-row">
              <input
                type="text"
                class="mod-checklist-row-label"
                placeholder={{i18n
                  "discourse_mod_categories.first_post_checklist.item_label"
                }}
                value={{row.label}}
                {{on "input" (fn this.updateLabel row)}}
              />
              <input
                type="text"
                class="mod-checklist-row-url"
                placeholder={{i18n
                  "discourse_mod_categories.first_post_checklist.item_url"
                }}
                value={{row.url}}
                {{on "input" (fn this.updateUrl row)}}
              />
              <div class="mod-checklist-row-controls">
                <DButton
                  @action={{fn this.moveRowUp row}}
                  @icon="arrow-up"
                  @title="discourse_mod_categories.first_post_checklist.move_up_item"
                  @disabled={{eq index 0}}
                  class="btn-flat mod-checklist-move-up"
                />
                <DButton
                  @action={{fn this.moveRowDown row}}
                  @icon="arrow-down"
                  @title="discourse_mod_categories.first_post_checklist.move_down_item"
                  @disabled={{eq index this.lastRowIndex}}
                  class="btn-flat mod-checklist-move-down"
                />
                <DButton
                  @action={{fn this.removeRow row}}
                  @icon="trash-can"
                  @title="discourse_mod_categories.first_post_checklist.remove_item"
                  class="btn-flat mod-checklist-remove"
                />
              </div>
            </div>
          {{/each}}
        </div>
      {{/if}}

      <div class="mod-checklist-field">
        <label class="mod-checklist-field-label">
          {{i18n
            "discourse_mod_categories.first_post_checklist.audience_label"
          }}
        </label>
        <ComboBox
          @value={{this.maxTl}}
          @content={{this.audienceOptions}}
          @onChange={{this.updateMaxTl}}
          class="mod-checklist-audience"
        />
      </div>

      <div class="mod-checklist-field">
        <label class="mod-checklist-field-label">
          {{i18n
            "discourse_mod_categories.first_post_checklist.button_label_label"
          }}
        </label>
        <input
          type="text"
          class="mod-checklist-button-label"
          placeholder={{i18n
            "discourse_mod_categories.first_post_checklist.button_label_placeholder"
          }}
          value={{this.buttonLabel}}
          {{on "input" this.updateButtonLabel}}
        />
      </div>

      <div class="mod-checklist-editor-actions">
        <DButton
          @action={{this.addRow}}
          @icon="plus"
          @label="discourse_mod_categories.first_post_checklist.add_item"
          class="mod-checklist-add"
        />
        <DButton
          @action={{this.save}}
          @label="discourse_mod_categories.first_post_checklist.save"
          @disabled={{this.saving}}
          class="btn-primary mod-checklist-save"
        />
        {{#if this.saved}}
          <span class="mod-checklist-saved">
            {{i18n "discourse_mod_categories.first_post_checklist.saved"}}
          </span>
        {{/if}}
      </div>

      <section class="mod-checklist-log">
        <div class="mod-checklist-log-header">
          <h3 class="mod-checklist-log-title">
            {{i18n "discourse_mod_categories.first_post_checklist.log_title"}}
            <span class="mod-checklist-log-count">
              {{this.filteredLog.length}}
            </span>
          </h3>
          {{#if this.version}}
            <label class="mod-checklist-log-filter">
              <input
                type="checkbox"
                checked={{this.onlyCurrentVersion}}
                {{on "change" this.toggleLogFilter}}
              />
              {{i18n
                "discourse_mod_categories.first_post_checklist.log_filter_current"
                count=this.version
              }}
            </label>
          {{/if}}
        </div>
        {{#if this.filteredLog.length}}
          <table class="mod-checklist-log-table">
            <thead>
              <tr>
                <th>
                  {{i18n
                    "discourse_mod_categories.first_post_checklist.log_user"
                  }}
                </th>
                <th>
                  {{i18n
                    "discourse_mod_categories.first_post_checklist.log_version"
                  }}
                </th>
                <th>
                  {{i18n
                    "discourse_mod_categories.first_post_checklist.log_when"
                  }}
                </th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each this.filteredLog as |entry|}}
                <tr>
                  <td>
                    <a
                      href={{concat "/u/" entry.username}}
                      data-user-card={{entry.username}}
                    >{{entry.username}}</a>
                  </td>
                  <td>{{entry.version}}</td>
                  <td>{{ageWithTooltip entry.at}}</td>
                  <td>
                    <DButton
                      @action={{fn this.requireReaccept entry}}
                      @label="discourse_mod_categories.first_post_checklist.require_reaccept"
                      class="btn-flat mod-checklist-require-reaccept"
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <p class="mod-checklist-log-empty">
            {{i18n "discourse_mod_categories.first_post_checklist.log_empty"}}
          </p>
        {{/if}}
      </section>

      <section class="mod-checklist-targeted">
        <h3 class="mod-checklist-targeted-title">
          {{i18n
            "discourse_mod_categories.first_post_checklist.targeted_title"
          }}
        </h3>
        <p class="mod-checklist-targeted-intro">
          {{i18n
            "discourse_mod_categories.first_post_checklist.targeted_intro"
          }}
        </p>

        {{#each this.targeted as |checklist|}}
          <div class="mod-checklist-targeted-item">
            {{#if checklist.version}}
              <p class="mod-checklist-version">
                {{i18n
                  "discourse_mod_categories.first_post_checklist.current_version"
                  count=checklist.version
                }}
              </p>
            {{/if}}

            <div class="mod-checklist-field">
              <label class="mod-checklist-field-label">
                {{i18n
                  "discourse_mod_categories.first_post_checklist.targeted_name_label"
                }}
              </label>
              <input
                type="text"
                class="mod-checklist-targeted-name"
                value={{checklist.name}}
                {{on "input" (fn this.updateTargetedName checklist)}}
              />
            </div>

            <div class="mod-checklist-field">
              <label class="mod-checklist-field-label">
                {{i18n
                  "discourse_mod_categories.first_post_checklist.targeted_users_label"
                }}
              </label>
              <EmailGroupUserChooser
                @value={{checklist.usernames}}
                @onChange={{fn this.updateTargetedUsers checklist}}
                @options={{hash includeGroups=false}}
                class="mod-checklist-targeted-users"
              />
            </div>

            {{#if checklist.rows.length}}
              <div class="mod-checklist-rows">
                {{#each checklist.rows as |row|}}
                  <div class="mod-checklist-row">
                    <input
                      type="text"
                      class="mod-checklist-row-label"
                      placeholder={{i18n
                        "discourse_mod_categories.first_post_checklist.item_label"
                      }}
                      value={{row.label}}
                      {{on "input" (fn this.updateTargetedLabel row)}}
                    />
                    <input
                      type="text"
                      class="mod-checklist-row-url"
                      placeholder={{i18n
                        "discourse_mod_categories.first_post_checklist.item_url"
                      }}
                      value={{row.url}}
                      {{on "input" (fn this.updateTargetedUrl row)}}
                    />
                    <DButton
                      @action={{fn this.removeTargetedRow checklist row}}
                      @icon="trash-can"
                      @title="discourse_mod_categories.first_post_checklist.remove_item"
                      class="btn-flat mod-checklist-remove"
                    />
                  </div>
                {{/each}}
              </div>
            {{/if}}

            <div class="mod-checklist-field">
              <label class="mod-checklist-field-label">
                {{i18n
                  "discourse_mod_categories.first_post_checklist.button_label_label"
                }}
              </label>
              <input
                type="text"
                class="mod-checklist-button-label"
                placeholder={{i18n
                  "discourse_mod_categories.first_post_checklist.button_label_placeholder"
                }}
                value={{checklist.buttonLabel}}
                {{on "input" (fn this.updateTargetedButtonLabel checklist)}}
              />
            </div>

            <div class="mod-checklist-editor-actions">
              <DButton
                @action={{fn this.addTargetedRow checklist}}
                @icon="plus"
                @label="discourse_mod_categories.first_post_checklist.add_item"
                class="mod-checklist-targeted-add-item"
              />
              <DButton
                @action={{fn this.saveTargeted checklist}}
                @label="discourse_mod_categories.first_post_checklist.targeted_save"
                @disabled={{this.saving}}
                class="btn-primary mod-checklist-targeted-save"
              />
              <DButton
                @action={{fn this.deleteTargeted checklist}}
                @icon="trash-can"
                @label="discourse_mod_categories.first_post_checklist.targeted_delete"
                class="btn-danger mod-checklist-targeted-delete"
              />
            </div>
          </div>
        {{/each}}

        <DButton
          @action={{this.addTargeted}}
          @icon="plus"
          @label="discourse_mod_categories.first_post_checklist.targeted_add"
          class="mod-checklist-targeted-add"
        />
      </section>
    </div>
  </template>
}
