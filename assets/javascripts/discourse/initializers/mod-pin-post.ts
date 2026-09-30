import type Owner from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import type Topic from "discourse/models/topic";
import type User from "discourse/models/user";
import type AppEventsService from "discourse/services/app-events";
import type SiteSettings from "discourse/services/site-settings";

interface PinPostSiteSettings {
  mod_categories_enabled: boolean;
  mod_pin_post_enabled: boolean;
}

type PinTopic = Topic & { mod_topic_pinned_post_id?: number | null };

interface PinPost {
  id: number;
  topic_id: number;
  topic?: PinTopic | null;
}

interface PinResponse {
  pinned_post_id: number | null;
  pinned_post?: object | null;
}

// Adds a "Pin to Bottom" / "Unpin from Bottom" button to the post admin
// menu (moderator actions), visible only to staff. Pinning records the
// post on the topic's `mod_topic_pinned_post_id` custom field; the topic
// footer connector then renders that post's content at the bottom.
export default {
  name: "discourse-mod-pin-post",

  initialize(container: Owner) {
    const currentUser = container.lookup("service:current-user") as User | null;
    const siteSettings = container.lookup(
      "service:site-settings"
    ) as SiteSettings & PinPostSiteSettings;
    const appEvents = container.lookup(
      "service:app-events"
    ) as AppEventsService;

    if (
      !currentUser ||
      !currentUser.staff ||
      !siteSettings.mod_categories_enabled ||
      !siteSettings.mod_pin_post_enabled
    ) {
      return;
    }

    withPluginApi((api) => {
      api.addPostAdminMenuButton((post: PinPost) => {
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
              const result: PinResponse = await ajax(
                `/discourse-mod-categories/topic/${post.topic_id}`,
                {
                  type: "PUT",
                  data: { pinned_post_id: pinned ? "" : post.id },
                }
              );
              topic?.set("mod_topic_pinned_post_id", result.pinned_post_id);
              topic?.set("mod_topic_pinned_post", result.pinned_post || null);
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
