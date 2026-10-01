import { settings, themePrefix } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import JtCommandMenu from "../components/jt-command-menu";

// ⌘K / Ctrl+K opens the command menu. Not global: inside the composer and
// other text fields Ctrl+K keeps meaning "insert link".
export default apiInitializer((api) => {
  if (!settings.command_menu) {
    return;
  }

  const modal = api.container.lookup("service:modal");

  api.addKeyboardShortcut(
    "mod+k",
    (event) => {
      event?.preventDefault();
      modal.show(JtCommandMenu);
    },
    {
      anonymous: true,
      help: {
        category: "application",
        name: themePrefix("jt.cmdk.shortcut_help"),
        definition: { keys1: ["mod", "k"] },
      },
    }
  );
});
