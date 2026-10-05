import type Owner from "@ember/owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { currentThemeId } from "discourse/lib/theme-selector";
import type SiteSettingsService from "discourse/services/site-settings";

interface RowClickSiteSettings {
  jtech_enabled: boolean;
  jtech_row_click_theme_ids: string;
}

interface TopicListItemClickContext {
  event: MouseEvent & { target: Element };
}

// On the themes in jtech_row_click_theme_ids (the forum's "Default"), a click
// anywhere on a topic list row opens the topic, as core already does on
// phones; on desktop core only answers the title and the numbers. Real
// links/buttons inside keep their own behaviour; modifier keys and
// middle-click open a new tab. The press bounce is jtech-row-click.scss,
// switched on by the html class. The JTech theme's cards do this themselves
// (themes/jtech/.../jt-topic-cards.gts), so leave JTech's id out of the setting.
export default {
  name: "jtech-row-click",

  initialize(container: Owner) {
    const siteSettings = container.lookup(
      "service:site-settings"
    ) as SiteSettingsService & RowClickSiteSettings;
    const themeIds = (siteSettings.jtech_row_click_theme_ids || "")
      .split("|")
      .filter(Boolean);
    if (
      !siteSettings.jtech_enabled ||
      !themeIds.includes(String(currentThemeId()))
    ) {
      return;
    }

    document.documentElement.classList.add("jtech-row-click");

    withPluginApi((api) => {
      api.registerBehaviorTransformer(
        "topic-list-item-click",
        ({
          context,
          next,
        }: {
          context: TopicListItemClickContext;
          next: () => void;
        }) => {
          const { event } = context;
          // Selecting text on a row (drag, then release) isn't a click to open it.
          if (window.getSelection()?.toString()) {
            return;
          }
          if (event.target.closest("a, button, input, label")) {
            return next();
          }

          const link = event.target
            .closest(".topic-list-item")
            ?.querySelector<HTMLAnchorElement>("a.raw-topic-link");
          if (!link) {
            return next();
          }
          event.preventDefault();
          event.stopPropagation();

          if (event.button === 1) {
            window.open(link.href, "_blank", "noopener,noreferrer");
            return;
          }
          link.dispatchEvent(
            new MouseEvent("click", {
              ctrlKey: event.ctrlKey,
              metaKey: event.metaKey,
              shiftKey: event.shiftKey,
              button: event.button,
              bubbles: true,
              cancelable: true,
            })
          );
        }
      );
    });
  },
};
