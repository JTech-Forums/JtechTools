import { settings } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import JtHeaderIcon from "../components/jt-header-icon";
import JtHeaderNewTopic from "../components/jt-header-new-topic";
import JtHeaderSearch from "../components/jt-header-search";
import { colorToggleAvailable } from "../lib/jt-color-mode";

// Header right, in order: search field (command menu) · JTech home ·
// messages · notifications · light/dark · new topic · avatar. Core's
// magnifier stays in the DOM, hidden while the search field shows
// (jt-header.scss), so "/" still opens core's search.
const icon = (kind, extra = {}) => <template>
  <JtHeaderIcon @href={{extra.href}} @kind={{kind}} />
</template>;

export default apiInitializer((api) => {
  const user = api.getCurrentUser();
  const site = api.container.lookup("service:site");
  const interfaceColor = api.container.lookup("service:interface-color");
  let previous = "search";
  const add = (key, component) => {
    api.headerIcons.add(key, component, {
      after: previous,
      before: "hamburger",
    });
    previous = key;
  };

  // The field replaces core's magnifier only when there's something to open:
  // the command menu, for visitors allowed to search.
  if (settings.command_menu && site.can_search) {
    document.documentElement.classList.add("jt-has-header-search");
    api.headerIcons.add("jt-search", JtHeaderSearch, { before: "search" });
  }
  if (settings.header_home_url) {
    add("jt-home", icon("home", { href: settings.header_home_url }));
  }
  if (user?.can_send_private_messages) {
    add("jt-messages", icon("messages"));
  }
  if (user) {
    add("jt-notifications", icon("notifications"));
  }
  if (colorToggleAvailable(interfaceColor)) {
    document.documentElement.classList.add("jt-has-color-toggle");
    add("jt-theme", icon("theme"));
  }
  add("jt-new-topic", JtHeaderNewTopic);
});
