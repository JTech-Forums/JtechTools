import { withPluginApi } from "discourse/lib/plugin-api";
import ModWhisperAddParticipantModal from "../components/mod-whisper-add-participant-modal";

// Adds an "Add user to whisper" button to a whisper post's admin menu,
// visible only to staff while whispers are enabled. It opens a user chooser
// modal that adds the chosen users to the topic's whisper conversation, so
// they see every whisper in the topic from then on.
export default {
  name: "discourse-mod-whisper-add-participant",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    const siteSettings = container.lookup("service:site-settings");

    if (
      !currentUser ||
      !currentUser.staff ||
      !siteSettings.mod_whisper_enabled
    ) {
      return;
    }

    const modal = container.lookup("service:modal");

    withPluginApi("1.0", (api) => {
      api.addPostAdminMenuButton((post) => {
        if (!post?.mod_is_whisper) {
          return;
        }

        return {
          icon: "user-plus",
          className: "mod-whisper-add-participant",
          label: "discourse_mod_categories.whisper.add_participant.menu_label",
          action: () =>
            modal.show(ModWhisperAddParticipantModal, { model: { post } }),
        };
      });
    });
  },
};
