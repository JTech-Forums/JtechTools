import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import JtCommandMenu from "./jt-command-menu";

const MAC = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);

// Header search: a field-shaped button ("Search… ⌘K") that opens the
// command menu; icon-only on narrow screens (jt-header.scss).
export default class JtHeaderSearch extends Component {
  @service modal;

  modKey = MAC ? "⌘" : "Ctrl";

  @action
  open() {
    this.modal.show(JtCommandMenu);
  }

  <template>
    <li class="header-dropdown-toggle jt-header-search">
      <button
        type="button"
        class="jt-header-search__button"
        aria-label={{i18n (themePrefix "jt.cmdk.sidebar_label")}}
        title={{i18n (themePrefix "jt.cmdk.sidebar_label")}}
        {{on "click" this.open}}
      >
        {{dIcon "magnifying-glass"}}
        <span class="jt-header-search__label">{{i18n
            (themePrefix "jt.header.search")
          }}</span>
        <span class="jt-header-search__keys" aria-hidden="true">
          <kbd>{{this.modKey}}</kbd><kbd>K</kbd>
        </span>
      </button>
    </li>
  </template>
}
