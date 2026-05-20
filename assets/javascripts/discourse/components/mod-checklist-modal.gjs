import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ModChecklistEditor from "./mod-checklist-editor";

// The first-post checklist config, shown in a modal opened from the
// sidebar. Loads the current checklist (and acceptance log) on open, then
// hands it to the editor.
export default class ModChecklistModal extends Component {
  @tracked data = null;
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    try {
      this.data = await ajax("/discourse-mod-categories/checklist");
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @title={{i18n
        "discourse_mod_categories.first_post_checklist.editor_title"
      }}
      @closeModal={{@closeModal}}
      class="mod-checklist-modal"
    >
      <:body>
        {{#if this.data}}
          <ModChecklistEditor @data={{this.data}} />
        {{else if this.loading}}
          <p class="mod-checklist-loading">
            {{i18n "discourse_mod_categories.first_post_checklist.loading"}}
          </p>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
