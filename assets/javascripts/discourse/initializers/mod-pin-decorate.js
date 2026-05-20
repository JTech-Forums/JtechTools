import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

// Marks the pinned post, in its real position in the post stream, with a
// "Pinned post" badge. Pairs with the bottom copy rendered by the
// topic-area-bottom connector — which is skipped when the pinned post is
// already the last post, so a last post just gets this badge.
export default {
  name: "discourse-mod-pin-decorate",

  initialize() {
    withPluginApi("1.0", (api) => {
      api.decorateCookedElement(
        (element, helper) => {
          const post = helper?.model;
          if (!post || !post.topic) {
            return;
          }

          const isPinned = post.topic.mod_topic_pinned_post_id === post.id;
          const existing = element.querySelector(".mod-pinned-in-stream-badge");

          if (!isPinned) {
            existing?.remove();
            return;
          }
          if (existing) {
            return;
          }

          const badge = document.createElement("div");
          badge.className = "mod-pinned-in-stream-badge";
          badge.innerHTML = `${iconHTML("thumbtack")} ${i18n(
            "discourse_mod_categories.pin_post.pinned_label"
          )}`;
          element.prepend(badge);
        },
        { onlyStream: true }
      );
    });
  },
};
