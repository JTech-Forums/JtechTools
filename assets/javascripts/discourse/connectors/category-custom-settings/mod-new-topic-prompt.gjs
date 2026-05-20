import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import { messageToHtml } from "../../lib/linkify-message";
import { trustLevelOptions } from "../../lib/trust-level-options";

// Field on the category edit screen letting a moderator set the
// "before you post a new topic" prompt for that category. Saves through
// the Guardian-gated plugin endpoint. Only rendered for existing
// categories (a new, unsaved category has no id).
export default class ModNewTopicPrompt extends Component {
  static shouldRender(args) {
    return !!(args && args.category && args.category.id);
  }

  audienceOptions = trustLevelOptions(true);

  get category() {
    return this.args.outletArgs.category;
  }

  @tracked prompt = this.category.mod_category_new_topic_prompt || "";
  @tracked maxTl = String(
    this.category.mod_category_new_topic_prompt_max_tl ?? 4
  );
  @tracked saving = false;
  @tracked saved = false;

  // Live preview of how the prompt will look in the confirmation dialog.
  get previewHtml() {
    return messageToHtml(this.prompt);
  }

  @action
  updatePrompt(event) {
    this.prompt = event.target.value;
    this.saved = false;
  }

  @action
  updateMaxTl(value) {
    this.maxTl = value;
    this.saved = false;
  }

  @action
  async save() {
    this.saving = true;

    try {
      const result = await ajax(
        `/discourse-mod-categories/category/${this.category.id}`,
        {
          type: "PUT",
          data: {
            new_topic_prompt: this.prompt,
            new_topic_prompt_max_tl: this.maxTl,
          },
        }
      );

      this.category.set(
        "mod_category_new_topic_prompt",
        result.new_topic_prompt
      );
      this.category.set(
        "mod_category_new_topic_prompt_max_tl",
        result.new_topic_prompt_max_tl
      );
      this.saved = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <section class="mod-new-topic-prompt field">
      <label class="mod-messages-label">
        {{i18n
          "discourse_mod_categories.category_settings.new_topic_prompt_label"
        }}
      </label>
      <p class="mod-messages-hint">
        {{i18n
          "discourse_mod_categories.category_settings.new_topic_prompt_hint"
        }}
      </p>
      <textarea
        class="mod-new-topic-prompt-input"
        rows="3"
        value={{this.prompt}}
        {{on "input" this.updatePrompt}}
      ></textarea>

      {{#if this.prompt}}
        <div class="mod-prompt-preview">
          <span class="mod-prompt-preview-label">
            {{i18n "discourse_mod_categories.category_settings.preview_label"}}
          </span>
          <div class="mod-prompt-preview-body">{{this.previewHtml}}</div>
        </div>
      {{/if}}

      <label class="mod-messages-label">
        {{i18n "discourse_mod_categories.audience.label"}}
      </label>
      <ComboBox
        @value={{this.maxTl}}
        @content={{this.audienceOptions}}
        @onChange={{this.updateMaxTl}}
        class="mod-new-topic-audience-input"
      />

      <div class="mod-new-topic-prompt-actions">
        <DButton
          @action={{this.save}}
          @label="discourse_mod_categories.category_settings.save"
          @disabled={{this.saving}}
          class="btn-primary mod-save-new-topic-prompt"
        />
        {{#if this.saved}}
          <span class="mod-saved-indicator">
            {{i18n "discourse_mod_categories.category_settings.saved"}}
          </span>
        {{/if}}
      </div>
    </section>
  </template>
}
