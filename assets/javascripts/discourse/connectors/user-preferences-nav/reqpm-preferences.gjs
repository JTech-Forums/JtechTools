import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

// "REQ-PM" tab in your own preferences.
export default class ReqpmPreferencesNav extends Component {
  static shouldRender({ model }, { currentUser }) {
    return !!currentUser?.reqpm?.available && model?.id === currentUser.id;
  }

  <template>
    <li class="user-nav__preferences-reqpm">
      <LinkTo @route="preferences.reqpm">
        {{icon "address-card"}}
        <span>{{i18n "reqpm.preferences.nav"}}</span>
      </LinkTo>
    </li>
  </template>
}
