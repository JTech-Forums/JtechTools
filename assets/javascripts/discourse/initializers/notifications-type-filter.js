import { withPluginApi } from "discourse/lib/plugin-api";
import NotificationsTypeFilter from "../components/notifications-type-filter";

// Adds a second filter dropdown to /u/{username}/notifications, sitting
// next to Discourse's existing All / Read / Unread filter. The dropdown
// sets ?type=<name>, the route picks it up as a queryParam, and the
// server's NotificationsController patch (sub_plugins/mod_categories.rb)
// scopes the result set accordingly. Staff-only `mod_notes` is gated on
// both sides — the dropdown hides it for non-staff and the controller
// drops the filter silently if a non-staff user passes it via the URL.
export default {
  name: "discourse-mod-notifications-type-filter",

  initialize() {
    withPluginApi("1.8.0", (api) => {
      api.renderInOutlet(
        "user-notifications-list-top",
        NotificationsTypeFilter
      );

      // Declare `type` so Ember serializes/deserializes it on the URL
      // and the dropdown can read it back via router.currentRoute.
      api.modifyClass("controller:user-notifications-index", {
        pluginId: "discourse-mod-categories-notifications-filter",
        queryParams: ["filter", "type"],
        type: null,
      });

      // Refresh the model whenever the dropdown changes so the new
      // type is reflected in the AJAX request. We re-issue the standard
      // store.findFiltered("notification", ...) call with `type` mixed
      // into the filter hash — Discourse's notification adapter passes
      // unknown filter keys straight through as query params.
      api.modifyClass("route:user-notifications-index", {
        pluginId: "discourse-mod-categories-notifications-filter",
        queryParams: {
          filter: { refreshModel: true },
          type: { refreshModel: true },
        },

        model(params) {
          const user = this.modelFor("user");
          const filter = { username: user.username };
          if (params.filter && params.filter !== "all") {
            filter.filter = params.filter;
          }
          if (params.type && params.type !== "all") {
            filter.type = params.type;
          }
          return this.store.findFiltered("notification", { filter });
        },
      });
    });
  },
};
