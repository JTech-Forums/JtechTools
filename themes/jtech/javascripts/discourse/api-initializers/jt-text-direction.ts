import { apiInitializer } from "discourse/lib/api";
import type SiteSettingsService from "discourse/services/site-settings";

// Core's "support mixed text direction" lets a title, excerpt or post read in
// its own direction (Hebrew right to left, English left to right) whatever
// the interface's. The theme's excerpts cut short after a few lines follow
// it too (jt-cards, jt-lists, jt-groups, jt-badges, jt-banner); this marks
// the page while it's on.
export default apiInitializer((api) => {
  const siteSettings = api.container.lookup(
    "service:site-settings"
  ) as SiteSettingsService & { support_mixed_text_direction: boolean };

  if (siteSettings.support_mixed_text_direction) {
    document.documentElement.classList.add("jt-mixed-direction");
  }
});
