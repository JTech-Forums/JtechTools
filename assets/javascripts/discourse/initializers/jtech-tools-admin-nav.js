import { withPluginApi } from "discourse/lib/plugin-api";

// The nav registry is keyed on AdminPlugin#id, which is the plugin's
// DIRECTORY name on the server — not the metadata name. Core itself warns
// about installs where the two differ ("Plugin name is 'jtech-tools', but
// plugin directory is named 'JtechTools'"), and a standard
// `git clone .../JtechTools.git` produces exactly that. Register under
// every plausible id; extra keys in the registry are harmless.
const PLUGIN_IDS = ["jtech-tools", "JtechTools", "jtechtools", "JTechTools"];

// One tab per sub-plugin, in plugin.rb load order, plus core's own
// all-settings tab kept last (if omitted, core unshifts it to position 0
// with its default label). The index route redirects to the first
// non-settings link, so Dislike is the landing tab.
const LINKS = [
  {
    label: "jtech_tools.admin.tabs.dislike",
    route: "adminPlugins.show.jtech-tools-dislike",
  },
  {
    label: "jtech_tools.admin.tabs.smtp",
    route: "adminPlugins.show.jtech-tools-smtp",
  },
  {
    label: "jtech_tools.admin.tabs.mini_mod",
    route: "adminPlugins.show.jtech-tools-mini-mod",
  },
  {
    label: "jtech_tools.admin.tabs.mod",
    route: "adminPlugins.show.jtech-tools-mod",
  },
  {
    label: "jtech_tools.admin.tabs.dumbcourse",
    route: "adminPlugins.show.jtech-tools-dumbcourse",
  },
  {
    label: "jtech_tools.admin.tabs.translator",
    route: "adminPlugins.show.jtech-tools-translator",
  },
  {
    label: "jtech_tools.admin.tabs.smart_search",
    route: "adminPlugins.show.jtech-tools-smart-search",
  },
  {
    label: "jtech_tools.admin.tabs.popups",
    route: "adminPlugins.show.jtech-tools-popups",
  },
  {
    label: "jtech_tools.admin.tabs.disteleplus",
    route: "adminPlugins.show.jtech-tools-disteleplus",
  },
  {
    label: "jtech_tools.admin.tabs.all_settings",
    route: "adminPlugins.show.settings",
  },
];

export default {
  name: "jtech-tools-admin-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }
    withPluginApi((api) => {
      PLUGIN_IDS.forEach((id) => {
        api.setAdminPluginIcon(id, "wrench");
        // Fresh copy per id: the nav manager mutates the stored array
        // (unshift of the settings link when absent).
        api.addAdminPluginConfigurationNav(id, [...LINKS]);
      });
    });
  },
};
