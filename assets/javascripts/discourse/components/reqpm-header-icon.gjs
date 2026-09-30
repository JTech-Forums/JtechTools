import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

// Header shortcut to /reqpm, with a badge while requests are waiting.
export default class ReqpmHeaderIcon extends Component {
  @service reqpm;
  @service router;

  get href() {
    return getURL("/reqpm");
  }

  get isActive() {
    return this.router.currentRouteName === "reqpm";
  }

  get count() {
    return this.reqpm.incomingCount;
  }

  get title() {
    return this.count
      ? i18n("reqpm.header.title_with_count", { count: this.count })
      : i18n("reqpm.header.title");
  }

  <template>
    <li
      class="header-dropdown-toggle reqpm-header-icon
        {{if this.isActive 'active'}}"
    >
      <DButton
        @href={{this.href}}
        @translatedTitle={{this.title}}
        @translatedAriaLabel={{this.title}}
        class="icon btn-flat {{if this.isActive 'active'}}"
      >
        {{icon "address-card"}}
        {{#if this.count}}
          <span class="reqpm-header-icon__badge">{{this.count}}</span>
        {{/if}}
      </DButton>
    </li>
  </template>
}
