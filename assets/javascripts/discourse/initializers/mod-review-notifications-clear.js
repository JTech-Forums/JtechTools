import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";

const REVIEW_URL_RE = /^\/review(?:\/(\d+))?(?:\?.*)?$/;

// Marks the current user's mod_note notifications whose URL points at
// /review/... as read whenever they navigate to /review or /review/:id.
//
// Without this, a staff member who lands on the review queue via a
// bookmark, a direct URL paste, or a link from outside the bell drop-
// down would see the related flag_note / post_rejected / post_approved
// notifications stay unread in the shield-tab and bell badge — only the
// bell-click path and the shield-tab-open path mark them read otherwise.
//
// When the URL targets a specific reviewable (/review/123), the id is
// forwarded so the backend can scope mark-as-read to that ONE row.
// Without that scoping, clicking a single notification swept every
// other reviewable's notifications read too — the exact bug reported
// after the staff-streams rollout. Hitting /review (the index) keeps
// the broad sweep since the staff member is viewing everything at once.
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
        const match = url.match(REVIEW_URL_RE);
        if (!match) {
          return;
        }
        const reviewableId = match[1];
        const data = reviewableId ? { reviewable_id: reviewableId } : {};
        ajax("/discourse-mod-categories/review/notifications/seen", {
          type: "POST",
          data,
        }).catch(() => {
          // Silent — marking-read on review-page open is best-effort.
          // A failure here just means the notification stays unread,
          // which is the pre-fix state.
        });
      });
    });
  },
};
