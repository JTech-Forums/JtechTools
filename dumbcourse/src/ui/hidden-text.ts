// Spoilers and [details] blocks in a post. A post is one D-pad stop (the
// links and summaries inside it are skipped so Down keeps reading), so
// hidden text is shown and hidden from the post's menu instead.

import { $$, toggleClass } from "../dom.ts";

export interface HiddenParts {
  spoilers: Element[];
  details: Element[];
}

let detailsWork: boolean | null = null;

export function hiddenParts(post: ParentNode): HiddenParts {
  // Engines without <details> (KaiOS 2.5) show its text already.
  if (detailsWork === null)
    detailsWork = "open" in document.createElement("details");
  return {
    spoilers: $$('[data-act="spoiler"]', post),
    details: detailsWork ? $$("details", post) : [],
  };
}

// "hidden" while any of it is still covered, "shown" once all of it is
// open, null when the post has none.
export function hiddenState(p: HiddenParts): "hidden" | "shown" | null {
  if (!p.spoilers.length && !p.details.length) return null;
  for (let i = 0; i < p.spoilers.length; i++)
    if (!p.spoilers[i].classList.contains("revealed")) return "hidden";
  for (let i = 0; i < p.details.length; i++)
    if (!p.details[i].hasAttribute("open")) return "hidden";
  return "shown";
}

export function showHidden(p: HiddenParts, show: boolean): void {
  for (let i = 0; i < p.spoilers.length; i++)
    toggleClass(p.spoilers[i], "revealed", show);
  for (let i = 0; i < p.details.length; i++) {
    if (show) p.details[i].setAttribute("open", "");
    else p.details[i].removeAttribute("open");
  }
}
