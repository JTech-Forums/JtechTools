import { withPluginApi } from "discourse/lib/plugin-api";

// Restyles Telegram-bridged chat messages — the ones the bridge bot posts
// with a "**Name (TG):**" prefix — as compact cards with the sender's name
// as a small header line (plus a "Telegram" pill, added in CSS) instead of
// inline bold text. Detection is purely content-shape based: a leading
// <strong> ending in "(TG):", which only the bridge's Formatter produces.
// Messages posted as a MATCHED Discourse user carry no prefix and keep the
// native chat look.
const SENDER_SUFFIX = /\s*\(TG\):$/;

export default {
  name: "disteleplus-bridged-messages",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.disteleplus_enabled) {
      return;
    }

    withPluginApi("1.0", (api) => {
      // Only present when the chat plugin is installed.
      if (!api.decorateChatMessage) {
        return;
      }

      api.decorateChatMessage(
        (element) => {
          const strong = element.querySelector(
            "p:first-child > strong:first-child"
          );
          if (!strong || !SENDER_SUFFIX.test(strong.textContent.trim())) {
            return;
          }
          if (element.classList.contains("disteleplus-bridged")) {
            return;
          }

          element.classList.add("disteleplus-bridged");
          strong.classList.add("disteleplus-bridged__sender");
          strong.textContent = strong.textContent
            .trim()
            .replace(SENDER_SUFFIX, "");

          // Drop the space that separated the prefix from the body — the
          // sender renders as its own line now.
          const next = strong.nextSibling;
          if (next?.nodeType === Node.TEXT_NODE) {
            next.textContent = next.textContent.replace(/^\s+/, "");
          }
        },
        { id: "disteleplus-bridged" }
      );
    });
  },
};
