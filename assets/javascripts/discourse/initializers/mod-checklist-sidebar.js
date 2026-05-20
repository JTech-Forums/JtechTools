import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import ModChecklistModal from "../components/mod-checklist-modal";

// Adds a "First-post checklist" link to the sidebar Community section
// (staff only). The link opens the checklist config in a modal — section
// links can only navigate, so the link renders with an inert href and a
// delegated click handler opens the modal instead.
export default {
  name: "discourse-mod-checklist-sidebar",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.staff) {
      return;
    }

    withPluginApi("1.0", (api) => {
      api.addCommunitySectionLink({
        name: "mod-checklist",
        href: "#",
        title: i18n(
          "discourse_mod_categories.first_post_checklist.sidebar_title"
        ),
        text: i18n(
          "discourse_mod_categories.first_post_checklist.sidebar_text"
        ),
        icon: "list-check",
      });
    });

    const modal = container.lookup("service:modal");
    document.addEventListener("click", (event) => {
      const link = event.target.closest(
        '[data-list-item-name="mod-checklist"]'
      );
      if (!link) {
        return;
      }
      event.preventDefault();
      modal.show(ModChecklistModal);
    });
  },
};
