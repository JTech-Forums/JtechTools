import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import ModPostViewers from "../components/mod-post-viewers";

// Staff action on forum posts: "See message viewers" — who has read this
// post (core post_timings) and when they last visited the topic.
export default {
  name: "mod-post-viewers",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");
    if (!siteSettings.mod_categories_enabled || !currentUser?.staff) {
      return;
    }

    withPluginApi("1.0", (api) => {
      api.addPostAdminMenuButton((post) => {
        return {
          icon: "eye",
          className: "mod-post-viewers-button",
          label: "discourse_mod_categories.post_viewers.label",
          action: async () => {
            try {
              const data = await ajax(
                `/discourse-mod-categories/post/${post.id}/viewers`
              );
              const modal = container.lookup("service:modal");
              modal.show(ModPostViewers, {
                model: { count: data.count, viewers: data.viewers },
              });
            } catch (error) {
              popupAjaxError(error);
            }
          },
        };
      });
    });
  },
};
