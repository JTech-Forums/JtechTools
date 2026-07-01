import { withPluginApi } from "discourse/lib/plugin-api";
import JtechPopupNotification from "../components/jtech-popup-notification";

// Mounts the desktop pop-up notification host once, globally, into the
// always-present `above-footer` outlet. The component itself gates on
// desktop-only + the per-user preference + the site setting, so mounting
// it is cheap and inert when the feature is off. Skipped entirely when the
// master switch is off so no MessageBus subscription is even created.
export default {
  name: "jtech-desktop-popup-notifications",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.popup_notifications_enabled) {
      return;
    }

    withPluginApi("1.0", (api) => {
      api.renderInOutlet("above-footer", JtechPopupNotification);
    });
  },
};
