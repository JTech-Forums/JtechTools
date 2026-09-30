import { withPluginApi } from "discourse/lib/plugin-api";

// Mini-mods with mini_mod_manage_tags get the bulk "create tags" form on
// /tags (the staff-only wrench menu beside it is hidden by the
// tags-below-title connector). Tag renaming is already gated by
// currentUser.canEditTags, which reflects the server-side grant.
export default {
  name: "mini-mod-tags",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "controller:tags/index",
        (Superclass) =>
          class extends Superclass {
            get canAdminTags() {
              return !!(
                this.currentUser?.staff || this.currentUser?.can_admin_tags
              );
            }
          },
        undefined
      );
    });
  },
};
