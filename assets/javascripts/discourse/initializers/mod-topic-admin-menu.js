import { withPluginApi } from "discourse/lib/plugin-api";
import ModTopicMessagesModal from "../components/mod-topic-messages-modal";

// Adds a button to the topic admin (wrench) menu, visible only to staff
// (moderators and admins), that opens the modal for setting this topic's
// footer message and reply prompt.
export default {
  name: "discourse-mod-topic-admin-menu",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
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
