// Disteleplus chat lock — makes Discourse Chat exist solely for the bridged
// admin channel. When `disteleplus_lock_chat_ui` is on:
//   * the header chat button goes STRAIGHT to the bridged conversation
//     (capture-phase intercept on .chat-header-icon — verified against
//     core's chat/header/icon.gjs markup — since the button's own action
//     opens the drawer/index, not a channel);
//   * any chat "hub" route (index, channels, DMs, threads, browse,
//     new-message) redirects to the bridge channel as a backstop for
//     keyboard shortcuts and deep links;
//   * a body class scopes CSS (disteleplus.scss) that hides the create-DM /
//     create-channel / browse affordances.
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
    if (
      siteSettings.disteleplus_lock_chat_exempt_admins &&
      currentUser?.admin
    ) {
      return;
    }

    const channelUrl = `/chat/c/-/${siteSettings.disteleplus_chat_channel_id}`;

    withPluginApi("1.0", (api) => {
      document.body.classList.add("disteleplus-chat-locked");

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

      api.onPageChange((url) => {
        const path = url.split("?")[0];
        if (BLOCKED_ROUTES.some((route) => route.test(path))) {
          DiscourseURL.routeTo(channelUrl);
        }
      });
    });
  },
};
