import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { commandMenuShortcutBound } from "../lib/jt-command-menu-shortcut";
import JtCommandMenu from "./jt-command-menu";

// Header search: a field-shaped button ("Search… ⌘K") that opens the
// command menu; icon-only on narrow screens (jt-header.scss). The key hint
// only shows when the keys really open it.
export default class JtHeaderSearch extends Component {
  @service capabilities;
  @service modal;

  showKeys = commandMenuShortcutBound(getOwner(this));

  get modKey() {
    return this.capabilities.isApple ? "⌘" : "Ctrl";
  }

  @action
  open() {
    this.modal.show(JtCommandMenu);
  }

  <template>
    <li class="header-dropdown-toggle jt-header-search">
      <button
        aria-label={{i18n (themePrefix "jt.cmdk.sidebar_label")}}
        class="jt-header-search__button"
        title={{i18n (themePrefix "jt.cmdk.sidebar_label")}}
        type="button"
        {{on "click" this.open}}
      >
        {{dIcon "magnifying-glass"}}
        <span class="jt-header-search__label">{{i18n
            (themePrefix "jt.header.search")
          }}</span>
        {{#if this.showKeys}}
          <span aria-hidden="true" class="jt-header-search__keys">
            <kbd>{{this.modKey}}</kbd><kbd>K</kbd>
          </span>
        {{/if}}
      </button>
    </li>
  </template>
}
