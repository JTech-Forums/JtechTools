// Disteleplus chat landing + lock.
//
// LANDING (disteleplus_chat_button_opens_bridge, default on): the header
// chat button and the bare /chat page open the bridged conversation
// directly, for EVERYONE — admins included — whenever the bridge is enabled
// and a channel id is configured. Landing in the conversation is the point
// of the bridge; the DM index is never the right landing page.
//
// LOCK (disteleplus_lock_chat_ui): additionally, every chat "hub" route
// (channel list, DMs, threads, browse, new-message) redirects to the bridge
// channel, and a body class scopes CSS (disteleplus.scss) that hides the
// create-DM / create-channel / browse affordances. Exempt admins
// (disteleplus_lock_chat_exempt_admins) skip the lock half — they keep the
// full chat UI and can deep-link to DMs/browse — but the landing still
// applies to them.
//
// This is the cosmetic half; the real enforcement is the Guardian prepend
// in sub_plugins/disteleplus.rb, which refuses channel/DM creation
// server-side.
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";

const HUB_ROUTES = [
  /^\/chat\/direct-messages(\/|$)/,
  /^\/chat\/channels(\/|$)/,
  /^\/chat\/threads(\/|$)/,
  /^\/chat\/browse(\/|$)/,
  /^\/chat\/new-message(\/|$)/,
];

export default {
  name: "disteleplus-chat-lock",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (
      !siteSettings.disteleplus_enabled ||
      !siteSettings.disteleplus_chat_channel_id
    ) {
      return;
    }

    const currentUser = container.lookup("service:current-user");
    const exemptAdmin =
      siteSettings.disteleplus_lock_chat_exempt_admins && currentUser?.admin;
    const landing = siteSettings.disteleplus_chat_button_opens_bridge;
    const locked = siteSettings.disteleplus_lock_chat_ui && !exemptAdmin;

    if (!landing && !locked) {
      return;
    }

    const channelUrl = `/chat/c/-/${siteSettings.disteleplus_chat_channel_id}`;

    withPluginApi((api) => {
      if (landing) {
        // Header chat button → straight to the conversation (the button's
        // own action opens the drawer/index, not a channel).
        document.addEventListener(
          "click",
          (event) => {
            if (event.target?.closest?.(".chat-header-icon")) {
              event.preventDefault();
              event.stopPropagation();
              DiscourseURL.routeTo(channelUrl);
            }
          },
          { capture: true }
        );
      }

      if (locked) {
        document.body.classList.add("disteleplus-chat-locked");
      }

      api.onPageChange((url) => {
        const path = url.split("?")[0];
        // Bare /chat is the landing page — redirect it whenever the landing
        // is on; deeper hub pages only under the full lock.
        if (landing && /^\/chat\/?$/.test(path)) {
          DiscourseURL.routeTo(channelUrl);
          return;
        }
        if (locked && HUB_ROUTES.some((route) => route.test(path))) {
          DiscourseURL.routeTo(channelUrl);
        }
      });
    });
  },
};
