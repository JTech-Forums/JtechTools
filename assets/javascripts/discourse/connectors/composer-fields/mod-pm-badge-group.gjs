import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import ModPmBadgePicker from "../../components/mod-pm-badge-picker";

// "Add badge group" button rendered inside the composer-fields outlet
// whenever the composer is in private-message mode. Opens a modal that
// resolves a chosen badge to its current holders' usernames and splices
// them into the standard target_recipients field. From that point the PM
// is sent through Discourse's normal PostCreator path with no further
// plugin code — the audience is the snapshot of holders at send time.
export default class ModPmBadgeGroup extends Component {
  @service modal;

  get composer() {
    return this.args.outletArgs?.model;
  }

  get show() {
    const composer = this.composer;
    if (!composer) {
      return false;
    }
    return !!composer.privateMessage;
  }

  @action
  open() {
    const composer = this.composer;
    if (!composer) {
      return;
    }
    this.modal.show(ModPmBadgePicker, { model: { composer } });
  }

  <template>
    {{#if this.show}}
      <DButton
        @action={{this.open}}
        @icon="certificate"
        @label="discourse_mod_categories.pm_badge.button"
        class="btn-default mod-pm-badge-group-btn"
      />
    {{/if}}
  </template>
}
