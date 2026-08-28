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

      // No component:tag-info override: core's tag-info is template-only now
      // and its gate (@currentUser.canEditTags) already reflects the
      // plugin's can_edit_tag_names? Guardian override via the serializer.
    });
  },
};
