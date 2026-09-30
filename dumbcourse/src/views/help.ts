// Keys and shortcuts, for the D-pad and the keypad.

import { html, type SafeHtml } from "../html.ts";
import { focusContent } from "../nav.ts";
import type { RouteContext } from "../router.ts";
import { useScreen } from "./common.ts";

function table(title: string, rows: Array<[string, string]>): SafeHtml {
  return html`<h2 class="section-title">${title}</h2>
    <ul class="rows keys">
      ${rows.map(
        ([k, what]) =>
          html`<li class="row" tabindex="0">
            <kbd>${k}</kbd><span class="row-main">${what}</span>
          </li>`
      )}
    </ul>`;
}

export function helpRoute(ctx: RouteContext): void {
  const s = useScreen();
  s.title("Keys & shortcuts", { back: true });
  s.render(
    html`${table("Moving around", [
      ["↑ ↓", "Move (long posts scroll first)"],
      ["← →", "Tabs · previous / next post"],
      ["OK", "Open · post actions"],
      ["Left soft key", "Menu · Close"],
      ["Right soft key", "Options"],
      ["Back / ⌫", "Back · Close"],
    ])}
    ${table("Keypad, anywhere", [
      ["*", "Menu"],
      ["#", "Search"],
      ["0", "This help"],
      ["1", "Top of the page"],
      ["7", "Bottom of the page"],
      ["2 / 8", "Page up / page down"],
      ["4", "Back"],
    ])}
    ${table("In lists", [
      ["3", "Start a new topic"],
      ["5", "Refresh"],
      ["9", "Options"],
    ])}
    ${table("In a topic", [
      ["3", "Reply to this post"],
      ["5", "Like this post"],
      ["9", "Jump to a post number"],
      ["1 / 7", "First / last post"],
    ])}`
  );
  if (!ctx.restore) focusContent(".row");
}
