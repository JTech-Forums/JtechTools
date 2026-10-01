import type Owner from "@ember/owner";
import { settings } from "virtual:theme";

// The chat plugin's service, which @discourse/types doesn't describe
interface ChatService {
  userCanChat?: boolean;
}

// Whether ⌘K / Ctrl+K opens the command menu for this visitor. Core chat binds
// the same keys to its channel switcher for everyone who can chat; both would
// fire on one keypress, so the menu leaves the keys to chat then (the header's
// search field still opens it).
export function commandMenuShortcutBound(owner: Owner): boolean {
  if (!settings.command_menu) {
    return false;
  }
  const chat = owner.lookup("service:chat") as ChatService | undefined;
  return !chat?.userCanChat;
}
