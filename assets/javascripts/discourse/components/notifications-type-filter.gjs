import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

// Some plugin-defined notification types don't have a
// `notifications.titles.X` translation, in which case i18n() returns the
// bracketed placeholder "[en.notifications.titles.X]" — ugly inside a
// dropdown. discourse-i18n's default export is the `i18n` FUNCTION (not
// an I18n object with `.lookup`), so the cleanest probe is to call i18n
// and check for the bracket marker on the returned string. On a miss,
// fall back to a humanized version of the type name
// ("chat_group_mention" → "Chat group mention") so the row reads cleanly.
function nameForType(type) {
  const value = i18n(`notifications.titles.${type}`);
  if (value && !value.startsWith("[")) {
    return value;
  }
  return type.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
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
    // Read straight from window.location since `type` isn't a declared
    // controller queryParam (see the long note in the initializer about
    // why class-field queryParams can't be extended via api.modifyClass).
    if (typeof window === "undefined") {
      return ALL;
    }
    return new URLSearchParams(window.location.search).get("type") || ALL;
  }

  @action
  onChange(value) {
    // `router.transitionTo(path + ?type=...)` is a NO-OP here because
    // Ember treats the new URL as the same route — `type` isn't declared
    // as a controller queryParam (an Ember classic-reopen limitation
    // noted at length in the initializer), so the queryParam diff is
    // empty and the transition silently aborts WITHOUT touching the
    // URL. A pushState+router.refresh dance had a similar problem —
    // the Capybara assertion saw the URL revert.
    //
    // Falling back to a full navigation via `window.location.assign`
    // sidesteps the whole Ember queryParam dance. The page reloads,
    // route model() reads the fresh `?type=` from window.location, and
    // the filtered list renders. Slightly heavier than an in-app
    // transition, but the alternative is reaching into Discourse's
    // queryParam plumbing — and the filter pick happens infrequently
    // enough that a single reload is a fine UX trade.
    const url = new URL(window.location.href);
    if (value === ALL) {
      url.searchParams.delete("type");
    } else {
      url.searchParams.set("type", value);
    }
    window.location.assign(url.pathname + url.search);
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
