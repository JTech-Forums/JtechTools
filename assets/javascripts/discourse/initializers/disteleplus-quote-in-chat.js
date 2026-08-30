import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

// Mod action on forum posts: "Quote in chat" sends the post into the native
// disteleplus conversation as [quote] markup (the conversation cooks it into
// a full quote box, and the bridge relays it to Telegram). Staff-only, in the
// post wrench menu next to the other mod actions.
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
              await ajax("/jtech-disteleplus/quote", {
                type: "POST",
                data: { post_id: post.id },
              });
              container.lookup("service:toasts")?.success({
                duration: 4000,
                data: { message: i18n("disteleplus.quote_in_chat.success") },
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
