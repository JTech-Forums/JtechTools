import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// "+" in the header: start a topic from anywhere, in the category you're
// looking at when there is one.
export default class JtHeaderNewTopic extends Component {
  @service composer;
  @service currentUser;
  @service discovery;

  get show() {
    return this.currentUser?.can_create_topic;
  }

  @action
  newTopic() {
    this.composer.openNewTopic({
      category: this.discovery?.category,
      tags: this.discovery?.tag?.id ? [this.discovery.tag.id] : undefined,
    });
  }

  <template>
    {{#if this.show}}
      <li class="header-dropdown-toggle jt-header-new-topic">
        <button
          type="button"
          class="btn btn-flat no-text icon jt-header-icon"
          aria-label={{i18n (themePrefix "jt.cmdk.new_topic")}}
          title={{i18n (themePrefix "jt.cmdk.new_topic")}}
          {{on "click" this.newTopic}}
        >{{dIcon "plus"}}</button>
      </li>
    {{/if}}
  </template>
}
