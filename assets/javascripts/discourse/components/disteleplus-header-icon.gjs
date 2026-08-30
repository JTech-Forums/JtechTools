import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

// Header shortcut, modelled on core Chat's header icon: on desktop it toggles
// the bottom-right drawer (unless the user chose full page); on mobile it
// opens the full-page route. Rendered only for users the server allows.
export default class DisteleplusHeaderIcon extends Component {
  @service disteleplus;
  @service site;

  constructor() {
    super(...arguments);
    this.disteleplus.ensureLoaded().catch(() => {});
  }

  get href() {
    return getURL("/disteleplus");
  }

  get isActive() {
    return this.disteleplus.isActive;
  }

  get showBadge() {
    return this.disteleplus.unreadCount > 0 && !this.disteleplus.isActive;
  }

  @action
  open(event) {
    if (this.site.mobileView || this.disteleplus.isFullPagePreferred) {
      if (this.disteleplus.isFullPageActive) {
        event?.preventDefault?.();
        return;
      }
      return;
    }
    // Desktop drawer mode: the link is a fallback for middle-click / open in
    // new tab; a plain click toggles the drawer.
    event?.preventDefault?.();
    if (this.disteleplus.isFullPageActive) {
      return;
    }
    if (this.disteleplus.isDrawerActive) {
      this.disteleplus.closeDrawer();
    } else {
      this.disteleplus.prefersDrawer();
      this.disteleplus.openDrawer();
    }
  }

  <template>
    <li
      class="header-dropdown-toggle disteleplus-header-icon
        {{if this.isActive 'active'}}"
    >
      <DButton
        @action={{this.open}}
        @href={{this.href}}
        @forwardEvent={{true}}
        @translatedTitle={{i18n "disteleplus.title"}}
        @translatedAriaLabel={{i18n "disteleplus.title"}}
        class="icon btn-flat {{if this.isActive 'active'}}"
      >
        {{icon "comments"}}
        {{#if this.showBadge}}
          <span class="disteleplus-header-icon__badge">
            {{this.disteleplus.unreadCount}}
          </span>
        {{/if}}
      </DButton>
    </li>
  </template>
}
