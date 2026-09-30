import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ReqpmCardEditor from "./reqpm-card-editor";

// "Add a way for members to reach you" — shown to anyone who has nothing on
// their card yet, new and existing members alike. Gentle mode offers
// "Remind me later" and "I'd rather not"; required mode can only be closed
// by adding something (there is still a way to log out).
export default class ReqpmSetupModal extends Component {
  @service reqpm;
  @service currentUser;

  @tracked count = 0;
  @tracked busy = false;

  get required() {
    return this.args.model?.mode === "required";
  }

  get done() {
    return this.count > 0;
  }

  get dismissable() {
    return !this.required || this.done;
  }

  @action
  cardChanged(card) {
    this.count = card?.methods?.length || 0;
    if (this.done) {
      this.reqpm.clearSetupPrompt();
    }
  }

  @action
  finish() {
    this.args.closeModal();
  }

  @action
  async later() {
    this.busy = true;
    try {
      await this.reqpm.snoozeSetup();
      this.reqpm.clearSetupPrompt();
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.busy = false;
    }
  }

  @action
  async never() {
    this.busy = true;
    try {
      await this.reqpm.declineSetup();
      this.reqpm.clearSetupPrompt();
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.busy = false;
    }
  }

  @action
  logout() {
    this.currentUser.destroySession();
  }

  <template>
    <DModal
      @title={{i18n "reqpm.setup.title"}}
      @closeModal={{if this.dismissable @closeModal}}
      @dismissable={{this.dismissable}}
      class="reqpm-setup-modal"
    >
      <:body>
        <p class="reqpm-setup-modal__lead">{{i18n "reqpm.setup.lead"}}</p>

        <ReqpmCardEditor @startAdding={{true}} @onChange={{this.cardChanged}} />
      </:body>
      <:footer>
        {{#if this.done}}
          <DButton
            @action={{this.finish}}
            @icon="check"
            @label="reqpm.setup.done"
            class="btn-primary"
          />
        {{else if this.required}}
          <span class="reqpm-muted reqpm-setup-modal__required">{{i18n
              "reqpm.setup.required_note"
            }}</span>
          <DButton
            @action={{this.logout}}
            @label="reqpm.setup.log_out"
            class="btn-flat"
          />
        {{else}}
          <DButton
            @action={{this.later}}
            @label="reqpm.setup.later"
            @disabled={{this.busy}}
            class="btn-default"
          />
          <DButton
            @action={{this.never}}
            @label="reqpm.setup.never"
            @disabled={{this.busy}}
            class="btn-flat"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
