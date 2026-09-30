import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ReqpmCardEditor from "./reqpm-card-editor";

// Your own card and the "allow requests" switch. Used on the preferences
// tab and on the REQ-PM page's "My card" tab. Only ever shows the signed-in
// member's own card — an admin opening someone else's preferences gets a
// notice, not their own card by mistake.
export default class ReqpmPreferences extends Component {
  @service reqpm;
  @service currentUser;

  @tracked card = null;

  get isOwn() {
    return !this.args.user || this.args.user.id === this.currentUser?.id;
  }

  @action
  cardChanged(card) {
    this.card = card;
    this.args.onChange?.(card);
    if (card.methods.length) {
      this.reqpm.clearSetupPrompt();
    }
  }

  @action
  async toggleAllowRequests() {
    try {
      this.card = await this.reqpm.setAllowRequests(!this.card.allow_requests);
      this.args.onChange?.(this.card);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="reqpm-preferences">
      {{#if this.isOwn}}
        {{#if @showHeading}}
          <h3 class="reqpm-preferences__title">{{i18n
              "reqpm.preferences.title"
            }}</h3>
        {{/if}}
        <p class="reqpm-muted">{{i18n "reqpm.preferences.intro"}}</p>

        <ReqpmCardEditor @onChange={{this.cardChanged}} />

        {{#if this.card}}
          <div class="reqpm-setting">
            <DToggleSwitch
              @state={{this.card.allow_requests}}
              @label="reqpm.hub.allow_requests"
              {{on "click" this.toggleAllowRequests}}
            />
            <p class="reqpm-muted">{{i18n "reqpm.hub.allow_requests_hint"}}</p>
          </div>
        {{/if}}

        <p class="reqpm-muted reqpm-preferences__privacy">{{i18n
            "reqpm.hub.privacy_short"
          }}</p>

        {{#if @showHubLink}}
          <LinkTo @route="reqpm" class="reqpm-preferences__hub-link">
            {{i18n "reqpm.preferences.open_hub"}}
            →
          </LinkTo>
        {{/if}}
      {{else}}
        <p class="reqpm-muted">{{i18n "reqpm.preferences.not_yours"}}</p>
      {{/if}}
    </div>
  </template>
}
