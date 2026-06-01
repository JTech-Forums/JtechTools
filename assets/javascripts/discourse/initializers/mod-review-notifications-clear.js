import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";

const REVIEW_URL_RE = /^\/review(\/\d+)?(\?.*)?$/;

// Marks the current user's mod_note notifications whose URL points at
// /review/... as read whenever they navigate to /review or /review/:id.
//
// Without this, a staff member who lands on the review queue via a
// bookmark, a direct URL paste, or a link from outside the bell drop-
// down would see the related flag_note / post_rejected notifications
// stay unread in the shield-tab and bell badge — only the bell-click
// path and the shield-tab-open path mark them read otherwise.
//
// Backend filter pins this to mod_note rows whose `data.url` starts
// with /review, so we don't touch unrelated notifications.
export default {
  name: "discourse-mod-review-notifications-clear",

  initialize() {
    withPluginApi("1.0", (api) => {
      const currentUser = api.getCurrentUser();
      if (!currentUser || !currentUser.staff) {
        return;
      }

      api.onPageChange((url) => {
        if (typeof url !== "string") {
          return;
        }
        if (!REVIEW_URL_RE.test(url)) {
          return;
        }
        ajax("/discourse-mod-categories/review/notifications/seen", {
          type: "POST",
        }).catch(() => {
          // Silent — marking-read on review-page open is best-effort.
          // A failure here just means the notification stays unread,
          // which is the pre-fix state.
        });
      });
    });
  },
};
