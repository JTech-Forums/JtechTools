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
    html`<p class="hint pad">
        Dumbcourse works with the arrow keys and the number keys, like the
        phone's own apps. The bar at the bottom shows what the soft keys do
        right now.
      </p>
      ${table("Moving around", [
        [
          "↑ ↓",
          "Move up and down. On a long post, keeps reading before moving on.",
        ],
        ["← →", "Switch tabs; in a topic, jump to the previous or next post."],
        [
          "OK",
          "Open the thing you're on. On a post: its actions (like, reply, quote, links…).",
        ],
        ["Left soft key", "Menu (or Close, in a pop-up)"],
        ["Right soft key", "Options for this screen"],
        ["Back / ⌫", "Go back, or close the pop-up"],
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
        ["3", "Reply (to the post you're on)"],
        ["5", "Like the post you're on"],
        ["9", "Jump to a post number"],
        ["1 / 7", "First / last post"],
      ])}`
  );
  if (!ctx.restore) focusContent(".row");
}
