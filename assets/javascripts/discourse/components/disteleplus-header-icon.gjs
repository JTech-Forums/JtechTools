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
  @service router;

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

  // Mirrors Chat's header icon: full page on mobile or when the user chose
  // it; otherwise toggle the drawer. The href stays for middle-click.
  @action
  async open(event) {
    event?.preventDefault?.();

    // On the full page: leave it. Desktop goes back to the previous page with
    // the drawer open (Chat's "exit" behaviour); mobile just goes back.
    if (this.disteleplus.isFullPageActive) {
      const back = this.disteleplus.lastAppURL || "/";
      if (this.site.mobileView) {
        this.router.transitionTo(back);
        return;
      }
      this.disteleplus.prefersDrawer();
      await this.router.transitionTo(back);
      this.disteleplus.openDrawer();
      return;
    }

    if (this.site.mobileView || this.disteleplus.isFullPagePreferred) {
      this.router.transitionTo("/disteleplus");
      return;
    }

    if (this.disteleplus.isDrawerActive) {
      this.disteleplus.closeDrawer();
    } else {
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
        {{icon (if this.disteleplus.isFullPageActive "shuffle" "comments")}}
        {{#if this.showBadge}}
          <span class="disteleplus-header-icon__badge">
            {{this.disteleplus.unreadCount}}
          </span>
        {{/if}}
      </DButton>
    </li>
  </template>
}
