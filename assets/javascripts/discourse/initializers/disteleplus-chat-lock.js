// Disteleplus chat lock — makes Discourse Chat exist solely for the bridged
// admin channel. When `disteleplus_lock_chat_ui` is on:
//   * the header chat button goes STRAIGHT to the bridged conversation
//     (capture-phase intercept on .chat-header-icon — verified against
//     core's chat/header/icon.gjs markup — since the button's own action
//     opens the drawer/index, not a channel). This applies to EVERYONE,
//     exempt admins included: landing in the conversation is the point of
//     the feature, and the DM index is never the right landing page;
//   * any chat "hub" route (index, channels, DMs, threads, browse,
//     new-message) redirects to the bridge channel as a backstop for
//     keyboard shortcuts and deep links;
//   * a body class scopes CSS (disteleplus.scss) that hides the create-DM /
//     create-channel / browse affordances.
// Exempt admins (disteleplus_lock_chat_exempt_admins) skip the last two —
// they keep the full chat UI and can deep-link to DMs/browse — but the chat
// button still lands them in the bridge channel.
// This is the cosmetic half; the real enforcement is the Guardian prepend in
// sub_plugins/disteleplus.rb, which refuses channel/DM creation server-side.
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";

const BLOCKED_ROUTES = [
  /^\/chat\/?$/,
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
      !siteSettings.disteleplus_lock_chat_ui ||
      !siteSettings.disteleplus_chat_channel_id
    ) {
      return;
    }

    const currentUser = container.lookup("service:current-user");
    const exemptAdmin =
      siteSettings.disteleplus_lock_chat_exempt_admins && currentUser?.admin;

    const channelUrl = `/chat/c/-/${siteSettings.disteleplus_chat_channel_id}`;

    withPluginApi("1.0", (api) => {
      // The chat button always lands on the bridge conversation — even for
      // exempt admins, who otherwise land on an empty DM index.
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

      if (exemptAdmin) {
        return;
      }

      document.body.classList.add("disteleplus-chat-locked");

      api.onPageChange((url) => {
        const path = url.split("?")[0];
        if (BLOCKED_ROUTES.some((route) => route.test(path))) {
          DiscourseURL.routeTo(channelUrl);
        }
      });
    });
  },
};
