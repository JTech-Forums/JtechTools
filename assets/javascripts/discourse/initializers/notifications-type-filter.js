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
      // Renders directly inside `<div class="user-notifications-filter">`,
      // right after Discourse's built-in NotificationsFilter — so the two
      // dropdowns naturally sit side-by-side without any float / position
      // gymnastics. Outlet confirmed against
      // discourse/discourse:frontend/discourse/app/templates/user/notifications-index.gjs.
      api.renderInOutlet(
        "user-notifications-after-filter",
        NotificationsTypeFilter
      );

      // The userNotifications.index route inherits both controllerName and
      // model() from its parent `user-notifications` route, so that's where
      // queryParams and model() are actually defined — overriding the
      // `.index` route does nothing because it has no model() of its own.
      // See discourse/discourse: frontend/discourse/app/routes/user-notifications.js.
      api.modifyClass("controller:user-notifications", {
        pluginId: "discourse-mod-categories-notifications-filter",
        queryParams: ["filter", "type"],
        type: null,
      });

      // Mirror Discourse's stock model() body exactly (flat
      // `{ username, filter, limit }` hash passed to store.find — NOT
      // findFiltered, NOT a nested filter hash) and add our `type` key.
      // The server-side NotificationsController patch in
      // sub_plugins/mod_categories.rb translates ?type=... into the
      // existing filter_by_types mechanism or, for `mod_notes`, a custom
      // scoped index.
      api.modifyClass("route:user-notifications", {
        pluginId: "discourse-mod-categories-notifications-filter",
        queryParams: {
          filter: { refreshModel: true },
          type: { refreshModel: true },
        },

        model(params) {
          const username = this.modelFor("user").get("username");
          if (
            this.get("currentUser.username") !== username &&
            !this.get("currentUser.admin")
          ) {
            return;
          }
          const args = { username, filter: params.filter, limit: 60 };
          if (params.type && params.type !== "all") {
            args.type = params.type;
          }
          return this.store.find("notification", args);
        },
      });
    });
  },
};
