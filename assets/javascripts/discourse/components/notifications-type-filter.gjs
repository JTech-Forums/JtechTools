import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

// Label lookup order: our curated English name, then core's
// `notifications.titles.X`, then a humanized fallback for anything new —
// i18n() returns the bracketed "[en.…]" placeholder on a miss, so a bracket
// probe is the cleanest existence check discourse-i18n offers.
function nameForType(type) {
  const curated = i18n(
    `discourse_mod_categories.notification_type_filter.types.${type}`
  );
  if (curated && !curated.startsWith("[")) {
    return curated;
  }
  const core = i18n(`notifications.titles.${type}`);
  if (core && !core.startsWith("[")) {
    return core;
  }
  return type.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

// Second filter dropdown rendered next to Discourse's built-in
// All / Read / Unread filter on the user notifications page. Only types the
// user actually HAS notifications of are listed — a fresh account sees just
// "All types" instead of Discourse's entire catalogue. The `mod_notes`
// pseudo-type is staff-only and gated server-side too.
const ALL = "all";
const MOD_NOTES = "mod_notes";

export default class NotificationsTypeFilter extends Component {
  @service router;
  @service site;
  @service currentUser;

  @tracked availableTypes = null;
  @tracked hasModNotes = false;

  constructor() {
    super(...arguments);
    this.loadAvailableTypes();
  }

  async loadAvailableTypes() {
    try {
      const response = await ajax(
        "/discourse-mod-categories/notification-types"
      );
      this.availableTypes = response.types || [];
      this.hasModNotes = !!response.mod_notes;
    } catch {
      // Endpoint unavailable (older server) — fall back to every known type.
      this.availableTypes = Object.keys(this.site?.notification_types || {});
      this.hasModNotes = !!this.currentUser?.staff;
    }
  }

  get options() {
    const items = [
      {
        id: ALL,
        name: i18n("discourse_mod_categories.notification_type_filter.all"),
      },
    ];

    (this.availableTypes || [])
      .slice()
      .sort((a, b) => nameForType(a).localeCompare(nameForType(b)))
      .forEach((name) => {
        items.push({ id: name, name: nameForType(name) });
      });

    if (this.hasModNotes) {
      items.push({
        id: MOD_NOTES,
        name: i18n(
          "discourse_mod_categories.notification_type_filter.mod_notes"
        ),
      });
    }

    // A ?type= from the URL always stays selectable, even when the user has
    // no notifications of it (e.g. they just read the last one elsewhere).
    const selected = this.selectedValue;
    if (selected !== ALL && !items.some((item) => item.id === selected)) {
      items.push({ id: selected, name: nameForType(selected) });
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
