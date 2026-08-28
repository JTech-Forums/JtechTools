// Disteleplus chat landing + lock.
//
// LANDING (disteleplus_chat_button_opens_bridge, default on): the header
// chat button and the bare /chat page open the bridged conversation
// directly, for EVERYONE — admins included — whenever the bridge is enabled
// and a channel id is configured. Landing in the conversation is the point
// of the bridge; the DM index is never the right landing page.
//
// LOCK (disteleplus_lock_chat_ui) has two halves:
//   * creation — new channels, DMs and threads are hidden for EVERYONE,
//     admins included (body class `disteleplus-chat-locked`, CSS in
//     disteleplus.scss). There is no exemption; the server refuses these
//     for admins too.
//   * navigation — every chat "hub" route (channel list, DMs, threads,
//     browse, new-message) redirects to the bridge channel. Admins skip
//     THIS half when disteleplus_lock_chat_exempt_admins is on, so they can
//     still deep-link into DMs/browse to look around — they just cannot
//     create anything there.
//
// This is the cosmetic half; the real enforcement is the Guardian and
// Chat::Channel prepends in sub_plugins/disteleplus.rb.
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
    const creationLocked = siteSettings.disteleplus_lock_chat_ui;
    const hubLocked = creationLocked && !exemptAdmin;
    const notificationsForced =
      siteSettings.disteleplus_force_channel_notifications;

    if (!landing && !creationLocked && !notificationsForced) {
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

      if (creationLocked) {
        document.body.classList.add("disteleplus-chat-locked");
      }
      if (hubLocked) {
        document.body.classList.add("disteleplus-chat-hub-locked");
      }
      if (notificationsForced) {
        // Hides the per-channel notification-level controls for the bridge
        // channel; the server pins the level to "always" regardless, so
        // showing a control that snaps back would only confuse.
        document.body.classList.add("disteleplus-notifications-forced");
      }

      api.onPageChange((url) => {
        const path = url.split("?")[0];
        // Bare /chat is the landing page — redirect it whenever the landing
        // is on; deeper hub pages only under the navigation lock.
        if (landing && /^\/chat\/?$/.test(path)) {
          DiscourseURL.routeTo(channelUrl);
          return;
        }
        if (hubLocked && HUB_ROUTES.some((route) => route.test(path))) {
          DiscourseURL.routeTo(channelUrl);
        }
      });
    });
  },
};
