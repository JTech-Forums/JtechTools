import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";

// Adds a "Pin to Bottom" / "Unpin from Bottom" button to the post admin
// menu (moderator actions), visible only to staff. Pinning records the
// post on the topic's `mod_topic_pinned_post_id` custom field; the topic
// footer connector then renders that post's content at the bottom.
export default {
  name: "discourse-mod-pin-post",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    const siteSettings = container.lookup("service:site-settings");
    const appEvents = container.lookup("service:app-events");

    if (
      !currentUser ||
      !currentUser.staff ||
      !siteSettings.topic_footer_message_enabled
    ) {
      return;
    }

    withPluginApi("1.0", (api) => {
      api.addPostAdminMenuButton((post) => {
        const topic = post.topic;
        const pinned = !!topic && topic.mod_topic_pinned_post_id === post.id;

        return {
          icon: "thumbtack",
          className: "mod-pin-post-to-bottom",
          label: pinned
            ? "discourse_mod_categories.pin_post.unpin"
            : "discourse_mod_categories.pin_post.pin",
          action: async () => {
            try {
              const result = await ajax(
                `/discourse-mod-categories/topic/${post.topic_id}`,
                {
                  type: "PUT",
                  data: { pinned_post_id: pinned ? "" : post.id },
                }
              );
              topic?.set("mod_topic_pinned_post_id", result.pinned_post_id);
              if (topic) {
                appEvents.trigger("discourse-mod:messages-updated", topic);
                // Re-render the stream so the in-stream pin badge appears
                // or clears on the affected post immediately.
                appEvents.trigger("post-stream:refresh", { force: true });
              }
            } catch (error) {
              popupAjaxError(error);
            }
          },
        };
      });
    });
  },
};
