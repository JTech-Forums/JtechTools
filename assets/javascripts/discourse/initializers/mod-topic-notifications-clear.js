import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";

const TOPIC_URL_RE = /^\/t\/[^/]+\/(\d+)(?:\/\d+)?\/?$/;

// Marks the current user's custom mod-note + mod-whisper notifications
// for the topic they just opened as read. Discourse's built-in
// auto-mark-read only covers a hardcoded list of notification types
// and skips `custom`, so plugin notifications about a topic would sit
// unread in the bell forever even after the user opened the topic.
//
// Triggered on every page-change to a /t/<slug>/<id>[/<post_number>]
// URL. The backend filter pins this to OUR custom notifications only,
// so we don't touch notifications another plugin might attach to the
// same topic.
export default {
  name: "discourse-mod-topic-notifications-clear",

  initialize() {
    withPluginApi("1.0", (api) => {
      const currentUser = api.getCurrentUser();
      if (!currentUser) {
        return;
      }

      api.onPageChange((url) => {
        if (typeof url !== "string") {
          return;
        }
        const match = url.match(TOPIC_URL_RE);
        if (!match) {
          return;
        }
        const topicId = match[1];
        ajax(`/discourse-mod-categories/topic/${topicId}/notifications/seen`, {
          type: "POST",
        }).catch(() => {
          // Silent — marking-read on topic open is best-effort. A
          // failure here just means the notification stays unread,
          // which is the pre-fix state.
        });
      });
    });
  },
};
