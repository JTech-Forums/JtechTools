import { withPluginApi } from "discourse/lib/plugin-api";
import DisteleplusHeaderIcon from "../components/disteleplus-header-icon";

export default {
  name: "disteleplus-native",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");
    if (
      !siteSettings.disteleplus_enabled ||
      !currentUser?.can_access_disteleplus
    ) {
      return;
    }

    withPluginApi((api) => {
      api.headerIcons.add("disteleplus", DisteleplusHeaderIcon, {
        after: "search",
        before: "hamburger",
      });
    });
  },
};
