import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DisteleplusHeaderIcon extends Component {
  @service disteleplus;
  @service router;

  constructor() {
    super(...arguments);
    this.disteleplus.ensureLoaded().catch(() => {});
  }

  get href() {
    return getURL("/disteleplus");
  }

  get active() {
    return this.router.currentRouteName === "disteleplus";
  }

  @action
  open() {
    this.router.transitionTo("disteleplus");
  }

  <template>
    <li class="header-dropdown-toggle disteleplus-header-icon">
      <DButton
        @action={{this.open}}
        @href={{this.href}}
        class="icon btn-flat"
        title={{i18n "disteleplus.title"}}
        aria-label={{i18n "disteleplus.title"}}
      >
        {{dIcon "comments"}}
        {{#if this.disteleplus.unreadCount}}
          <span class="disteleplus-header-icon__badge">
            {{this.disteleplus.unreadCount}}
          </span>
        {{/if}}
      </DButton>
    </li>
  </template>
}
