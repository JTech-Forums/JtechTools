import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

// Header shortcut to /disteleplus with the server-derived unread badge. Only
// rendered for users the server says may access the conversation (see the
// disteleplus-native initializer).
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

  <template>
    <li
      class="header-dropdown-toggle disteleplus-header-icon
        {{if this.active 'active'}}"
    >
      <DButton
        @href={{this.href}}
        @translatedTitle={{i18n "disteleplus.title"}}
        @translatedAriaLabel={{i18n "disteleplus.title"}}
        class="icon btn-flat"
      >
        {{icon "comments"}}
        {{#if this.disteleplus.unreadCount}}
          <span class="disteleplus-header-icon__badge">
            {{this.disteleplus.unreadCount}}
          </span>
        {{/if}}
      </DButton>
    </li>
  </template>
}
