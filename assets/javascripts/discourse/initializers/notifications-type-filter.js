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
      // model() is actually defined — overriding the `.index` route does
      // nothing because it has no model() of its own. See discourse/
      // discourse: frontend/discourse/app/routes/user-notifications.js.
      //
      // We deliberately do NOT try to declare `type` as a controller
      // queryParam: Discourse's controller uses `queryParams = ["filter"]`,
      // a class FIELD, and Ember's classic reopen() (which api.modifyClass
      // uses under the hood) only patches prototype METHODS — it can't
      // override class-field initializers, so `type` would be silently
      // stripped from params before reaching model(). Instead we read
      // `type` directly from window.location.search inside model(); the
      // URL is the source of truth in either path (initial visit OR the
      // dropdown's router.transitionTo, which updates the location).
      //
      // The server-side NotificationsController patch in
      // sub_plugins/mod_categories.rb translates ?type=... into the
      // existing filter_by_types mechanism or, for `mod_notes`, a custom
      // scoped index.
      api.modifyClass("route:user-notifications", {
        pluginId: "discourse-mod-categories-notifications-filter",

        model(params) {
          const username = this.modelFor("user").get("username");
          if (
            this.get("currentUser.username") !== username &&
            !this.get("currentUser.admin")
          ) {
            return;
          }
          const args = { username, filter: params.filter, limit: 60 };
          const urlType = new URLSearchParams(window.location.search).get(
            "type"
          );
          if (urlType && urlType !== "all") {
            args.type = urlType;
          }
          return this.store.find("notification", args);
        },
      });
    });
  },
};
