import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import ModFirstPostChecklist from "../components/mod-first-post-checklist";
import {
  composerTopicId,
  firstPostChecklistFor,
  refreshOwedChecklist,
} from "../lib/first-post-checklist";
import { messageToHtml } from "../lib/linkify-message";
import {
  PRECHECK_CONFIRM_KEY,
  PRECHECK_GO_BACK_KEY,
  PRECHECK_TITLE_KEY,
  precheckPromptFor,
} from "../lib/precheck-prompt";

// Gates the composer submit, in order:
//   1. the forum-wide first-post checklist a new user must acknowledge;
//   2. the moderator's per-category (new topic) / per-topic (reply) prompt.
// `composerBeforeSave` replaces Composer#beforeSave, so a single handler
// runs both gates; each resolves when it does not apply, and a rejection
// aborts the save and keeps the composer open with content intact.
export default {
  name: "discourse-mod-precheck-prompt",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");

    // Shows the first-post checklist modal when the current user still
    // owes an acknowledgement; resolves immediately otherwise.
    //
    // The owed checklist is re-fetched from the server first so a version
    // bump made mid-session (no hard refresh) is still gated, and so an
    // already-accepted checklist is not re-shown.
    async function checklistGate(composer) {
      await refreshOwedChecklist(currentUser, composerTopicId(composer));

      const checklist = firstPostChecklistFor(composer, currentUser);
      if (!checklist) {
        return Promise.resolve();
      }

      const modal = container.lookup("service:modal");
      return new Promise((resolve, reject) => {
        modal.show(ModFirstPostChecklist, {
          model: { checklist, onAccept: resolve, onCancel: reject },
        });
      });
    }

    // Shows the moderator's confirmation prompt for this composer save.
    function precheckGate(composer) {
      const message = precheckPromptFor(composer, siteSettings, currentUser);
      if (!message) {
        return Promise.resolve();
      }

      const dialog = container.lookup("service:dialog");
      return new Promise((resolve, reject) => {
        dialog.confirm({
          message: messageToHtml(message),
          title: i18n(PRECHECK_TITLE_KEY),
          confirmButtonLabel: PRECHECK_CONFIRM_KEY,
          cancelButtonLabel: PRECHECK_GO_BACK_KEY,
          didConfirm: resolve,
          didCancel: reject,
        });
      });
    }

    withPluginApi("1.0", (api) => {
      // `checklistGate` re-fetches `/checklist/owed` before reading the
      // owed checklist, so a checklist version bumped by staff mid-session
      // is gated without the user needing a hard page refresh.
      api.composerBeforeSave(function () {
        const composer = this;
        return checklistGate(composer).then(() => precheckGate(composer));
      });
    });
  },
};
