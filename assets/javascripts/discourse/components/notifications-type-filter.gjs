import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import I18n, { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

// Some plugin-defined notification types don't have a
// `notifications.titles.X` translation, in which case i18n() returns the
// bracketed placeholder "[en.notifications.titles.X]" — ugly inside a
// dropdown. Probe the key with I18n.lookup() first; on a miss, fall back
// to a humanized version of the type name ("chat_group_mention" → "Chat
// group mention") so the row reads cleanly.
function nameForType(type) {
  const key = `notifications.titles.${type}`;
  if (typeof I18n?.lookup === "function" && I18n.lookup(key) != null) {
    return i18n(key);
  }
  return type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

// Second filter dropdown rendered next to Discourse's built-in
// All / Read / Unread filter on the user notifications page. Options come
// from `site.notification_types` so we automatically stay in sync as
// Discourse (or any plugin) adds new types. The `mod_notes` pseudo-type
// is staff-only and is gated server-side too — see the NotificationsController
// patch in sub_plugins/mod_categories.rb.
const ALL = "all";
const MOD_NOTES = "mod_notes";

export default class NotificationsTypeFilter extends Component {
  @service router;
  @service site;
  @service currentUser;

  get options() {
    const items = [
      {
        id: ALL,
        name: i18n("discourse_mod_categories.notification_type_filter.all"),
      },
    ];

    const types = this.site?.notification_types || {};
    Object.keys(types)
      .sort()
      .forEach((name) => {
        items.push({ id: name, name: nameForType(name) });
      });

    if (this.currentUser?.staff) {
      items.push({
        id: MOD_NOTES,
        name: i18n(
          "discourse_mod_categories.notification_type_filter.mod_notes"
        ),
      });
    }

    return items;
  }

  get selectedValue() {
    return this.router.currentRoute?.queryParams?.type || ALL;
  }

  @action
  onChange(value) {
    this.router.transitionTo({
      queryParams: { type: value === ALL ? null : value },
    });
  }

  <template>
    <div class="notifications-type-filter">
      <span class="filter-text">
        {{i18n "discourse_mod_categories.notification_type_filter.label"}}
      </span>
      <ComboBox
        @value={{this.selectedValue}}
        @content={{this.options}}
        @nameProperty="name"
        @valueProperty="id"
        @onChange={{this.onChange}}
        @options={{hash filterable=true}}
        class="notifications-type-filter-select"
      />
    </div>
  </template>
}
