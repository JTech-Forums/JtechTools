import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const count = new Intl.NumberFormat(undefined, { notation: "compact" });

// One header icon button. Kinds:
//  - home: a link (settings.header_home_url)
//  - notifications / messages: open core's user menu on that tab, with the
//    unread count as a badge (core's own menu, nothing duplicated)
//  - theme: light / dark
export default class JtHeaderIcon extends Component {
  @service currentUser;
  @service header;
  @service interfaceColor;
  @service router;

  get kind() {
    return this.args.kind;
  }

  get label() {
    return i18n(themePrefix(`jt.header.${this.kind}`));
  }

  get icon() {
    return {
      home: "house",
      messages: "envelope",
      notifications: "bell",
      theme: "circle-half-stroke",
    }[this.kind];
  }

  get unread() {
    const user = this.currentUser;
    if (!user) {
      return 0;
    }
    // get(): these are classic model properties; a plain read wouldn't be
    // tracked, so the badge would never update
    if (this.kind === "notifications") {
      return get(user, "all_unread_notifications_count") || 0;
    }
    if (this.kind === "messages") {
      return get(user, "new_personal_messages_notifications_count") || 0;
    }
    return 0;
  }

  get badge() {
    return this.unread > 0 ? count.format(this.unread) : null;
  }

  get tab() {
    return this.kind === "messages" ? "messages" : "all-notifications";
  }

  @action
  activate() {
    if (this.kind === "theme") {
      return this.toggleTheme();
    }

    const tabButton = () =>
      document.getElementById(`user-menu-button-${this.tab}`);
    const onThisTab = tabButton()?.classList.contains("active");

    if (this.header.userVisible && onThisTab) {
      document.getElementById("toggle-current-user")?.click(); // close
      return;
    }
    if (!this.header.userVisible) {
      document.getElementById("toggle-current-user")?.click();
    }
    // The menu renders over the next few frames; then pick the tab. If core's
    // menu ever changes shape, fall back to the full page.
    let frames = 30;
    const pick = () => {
      const button = tabButton();
      if (button) {
        if (!button.classList.contains("active")) {
          button.click();
        }
      } else if (--frames > 0) {
        requestAnimationFrame(pick);
      } else {
        this.router.transitionTo(
          this.kind === "messages" ? "/my/messages" : "/my/notifications"
        );
      }
    };
    schedule("afterRender", () => requestAnimationFrame(pick));
  }

  toggleTheme() {
    const dark = this.interfaceColor.colorModeIsDark
      ? true
      : this.interfaceColor.colorModeIsLight
        ? false
        : window.matchMedia("(prefers-color-scheme: dark)").matches;
    if (dark) {
      this.interfaceColor.forceLightMode();
    } else {
      this.interfaceColor.forceDarkMode();
    }
  }

  <template>
    <li class="header-dropdown-toggle jt-header-{{this.kind}}">
      {{#if @href}}
        <a
          class="btn btn-flat no-text icon jt-header-icon"
          href={{@href}}
          aria-label={{this.label}}
          title={{this.label}}
        >{{dIcon this.icon}}</a>
      {{else}}
        <button
          type="button"
          class="btn btn-flat no-text icon jt-header-icon"
          aria-label={{this.label}}
          title={{this.label}}
          {{on "click" this.activate}}
        >
          {{dIcon this.icon}}
          {{#if this.badge}}
            <span class="jt-header-icon__badge">{{this.badge}}</span>
          {{/if}}
        </button>
      {{/if}}
    </li>
  </template>
}
