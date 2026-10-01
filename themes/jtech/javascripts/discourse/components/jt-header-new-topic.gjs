import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// "+" in the header: start a topic from anywhere, in the category and tag
// you're looking at when there is one. Picks the category the way core's own
// New Topic button does (controllers/discovery/list.js).
export default class JtHeaderNewTopic extends Component {
  @service composer;
  @service currentUser;
  @service discovery;
  @service site;
  @service siteSettings;

  get show() {
    return this.currentUser?.can_create_topic && !this.site.isReadOnly;
  }

  get category() {
    const category = this.discovery?.category;
    if (!category || category.canCreateTopic) {
      return category;
    }
    if (this.siteSettings.default_subcategory_on_read_only_category) {
      return category.subcategoryWithCreateTopicPermission ?? category;
    }
    return category;
  }

  get tags() {
    const name = this.discovery?.tag?.name;
    return name && !["none", "all"].includes(name) ? name : undefined;
  }

  @action
  newTopic() {
    this.composer.openNewTopic({ category: this.category, tags: this.tags });
  }

  <template>
    {{#if this.show}}
      <li class="header-dropdown-toggle jt-header-new-topic">
        <button
          aria-label={{i18n (themePrefix "jt.cmdk.new_topic")}}
          class="btn btn-flat no-text icon jt-header-icon"
          title={{i18n (themePrefix "jt.cmdk.new_topic")}}
          type="button"
          {{on "click" this.newTopic}}
        >{{dIcon "plus"}}</button>
      </li>
    {{/if}}
  </template>
}
