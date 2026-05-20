import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import ModNotesPanel from "../components/mod-notes-panel";

// Registers a staff-only "Moderator notes" tab in the user menu, with the
// shield icon and an unread count, alongside the bell and other tabs.
export default {
  name: "discourse-mod-notes-tab",

  initialize() {
    withPluginApi("1.0", (api) => {
      api.registerUserMenuTab((UserMenuTab) => {
        return class extends UserMenuTab {
          get id() {
            return "discourse-mod-notes";
          }

          get panelComponent() {
            return ModNotesPanel;
          }

          get icon() {
            return "shield-halved";
          }

          get title() {
            return i18n("discourse_mod_categories.notes_tab.title");
          }

          get shouldDisplay() {
            return !!this.currentUser?.staff;
          }

          get count() {
            return this.currentUser?.mod_note_unread_count || 0;
          }
        };
      });
    });
  },
};
