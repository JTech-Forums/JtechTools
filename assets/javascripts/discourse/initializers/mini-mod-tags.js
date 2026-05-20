import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "mini-mod-tags",

  initialize() {
    withPluginApi("1.0", (api) => {
      api.modifyClass("controller:tags/index", {
        pluginId: "discourse-mini-mod",

        get canAdminTags() {
          return this.currentUser?.staff || this.currentUser?.can_admin_tags;
        },
      });

      api.modifyClass("component:tag-info", {
        pluginId: "discourse-mini-mod",

        get canAdminTag() {
          return this.currentUser?.staff || this.currentUser?.can_admin_tags;
        },
      });
    });
  },
};
