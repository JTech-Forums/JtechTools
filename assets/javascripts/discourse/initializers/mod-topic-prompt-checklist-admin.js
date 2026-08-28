import { withPluginApi } from "discourse/lib/plugin-api";
import ModTopicPromptChecklistModal from "../components/mod-topic-prompt-checklist-modal";

// Adds a dedicated "Prompt Checklist" entry to the topic admin (wrench)
// menu, separate from the "Moderator Actions" entry. Visible only to
// staff. Opens its own editor modal scoped to the current topic.
export default {
  name: "discourse-mod-topic-prompt-checklist-admin",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    const siteSettings = container.lookup("service:site-settings");
    if (
      !siteSettings.mod_categories_enabled ||
      !siteSettings.mod_topic_prompt_checklist_enabled
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
          icon: "list-check",
          className: "mod-topic-prompt-checklist-button",
          label: "discourse_mod_categories.topic_prompt_checklist.menu_label",
          action: () =>
            modal.show(ModTopicPromptChecklistModal, { model: { topic } }),
        };
      });
    });
  },
};
