import { withPluginApi } from "discourse/lib/plugin-api";
import ModTopicMessagesModal from "../components/mod-topic-messages-modal";

// Adds a button to the topic admin (wrench) menu, visible only to staff
// (moderators and admins), that opens the modal for setting this topic's
// footer message and reply prompt.
export default {
  name: "discourse-mod-topic-admin-menu",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    const siteSettings = container.lookup("service:site-settings");
    // The modal hosts three independent tools; show the menu entry while ANY
    // of them is enabled — gating on private notes alone used to remove the
    // footer and reply-approval UI when notes were switched off.
    if (
      !siteSettings.mod_categories_enabled ||
      (!siteSettings.mod_topic_private_notes_enabled &&
        !siteSettings.topic_footer_message_enabled &&
        !siteSettings.mod_topic_require_reply_approval_enabled)
    ) {
      return;
    }
    if (!currentUser || !currentUser.staff) {
      return;
    }

    const modal = container.lookup("service:modal");

    withPluginApi("1.0", (api) => {
      api.addTopicAdminMenuButton((topic) => {
        return {
          icon: "shield-halved",
          className: "mod-topic-messages-button",
          label: "discourse_mod_categories.topic_messages.menu_label",
          action: () => modal.show(ModTopicMessagesModal, { model: { topic } }),
        };
      });
    });
  },
};
