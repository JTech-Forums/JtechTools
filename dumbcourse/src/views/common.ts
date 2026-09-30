// Shared bits for views.

import { currentScreen, type Screen } from "../screen.ts";

// The Screen the router just began for this view.
export function useScreen(): Screen {
  const s = currentScreen();
  if (!s) throw new Error("No active screen");
  return s;
}
