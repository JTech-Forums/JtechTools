import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";

const EXCERPT_LENGTH = 300;

// Mod action on forum posts: "Quote in chat" opens the conversation with
// canonical [quote] markup prefilled in the composer, cursor ready for the
// staff member's own comment. Nothing posts until they hit send. The
// conversation cooks the markup into a full quote box, and the bridge
// relays the sent message to Telegram.
export default {
  name: "disteleplus-quote-in-chat",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");
    if (!siteSettings.disteleplus_enabled || !currentUser?.staff) {
      return;
    }

    withPluginApi("1.0", (api) => {
      api.addPostAdminMenuButton((post) => {
        return {
          icon: "comments",
          className: "disteleplus-quote-in-chat",
          label: "disteleplus.quote_in_chat.label",
          action: async () => {
            try {
              // The post-stream model carries cooked HTML only; quote bodies
              // take raw markdown, so fetch it.
              const data = await ajax(`/posts/${post.id}.json`);
              let excerpt = (data.raw || "").trim();
              if (excerpt.length > EXCERPT_LENGTH) {
                excerpt = `${excerpt.slice(0, EXCERPT_LENGTH).trimEnd()}…`;
              }
              const markup = `[quote="${data.username}, post:${data.post_number}, topic:${data.topic_id}"]\n${excerpt}\n[/quote]\n\n`;

              const disteleplus = container.lookup("service:disteleplus");
              disteleplus.setDraft(markup);
              // The route redirects to the drawer when that is the user's
              // preferred mode, so one entry point covers both shapes.
              DiscourseURL.routeTo("/disteleplus");
              discourseLater(() => {
                const textarea = document.querySelector(
                  ".disteleplus-composer textarea"
                );
                if (textarea) {
                  textarea.focus();
                  textarea.setSelectionRange(
                    textarea.value.length,
                    textarea.value.length
                  );
                  // Re-run autosize so the prefilled quote is fully visible.
                  textarea.dispatchEvent(new Event("input", { bubbles: true }));
                }
              }, 400);
            } catch (error) {
              popupAjaxError(error);
            }
          },
        };
      });
    });
  },
};
