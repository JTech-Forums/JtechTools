import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

// Where the desktop tab row is too narrow it scrolls sideways
// (jt-topic-list.scss). Bring the current tab into view, clear of the edge
// fade, so a page like "My posts" doesn't open with its own tab cut off.
// Phones don't scroll the row, so the overflow check covers them; reading
// site.mobileView here would be core's static-viewport deprecation.
const FADE = 32;

export default apiInitializer((api) => {
  api.onPageChange(() => {
    schedule("afterRender", () => {
      const tabs = document.getElementById("navigation-bar");
      const active = tabs?.querySelector(":scope > li.active");
      if (!active || tabs.scrollWidth <= tabs.clientWidth) {
        return;
      }
      const row = tabs.getBoundingClientRect();
      const tab = active.getBoundingClientRect();
      if (tab.left < row.left + FADE) {
        tabs.scrollLeft -= row.left + FADE - tab.left;
      } else if (tab.right > row.right - FADE) {
        tabs.scrollLeft += tab.right - (row.right - FADE);
      }
    });
  });
});
