import { settings } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import JtHeaderIcon from "../components/jt-header-icon";
import JtHeaderNewTopic from "../components/jt-header-new-topic";
import JtHeaderSearch from "../components/jt-header-search";

// Header right, in order: search field (command menu) · JTech home ·
// messages · notifications · light/dark · new topic · avatar. Core's
// magnifier stays in the DOM, hidden (jt-header.scss), so "/" still works.
const icon = (kind, extra = {}) =>
  <template><JtHeaderIcon @kind={{kind}} @href={{extra.href}} /></template>;

export default apiInitializer((api) => {
  const user = api.getCurrentUser();
  const interfaceColor = api.container.lookup("service:interface-color");
  let previous = "jt-search";
  const add = (key, component) => {
    api.headerIcons.add(key, component, { after: previous, before: "hamburger" });
    previous = key;
  };

  api.headerIcons.add("jt-search", JtHeaderSearch, { before: "search" });
  if (settings.header_home_url) {
    add("jt-home", icon("home", { href: settings.header_home_url }));
  }
  if (user) {
    add("jt-messages", icon("messages"));
    add("jt-notifications", icon("notifications"));
  }
  if (interfaceColor?.selectorAvailable) {
    add("jt-theme", icon("theme"));
  }
  add("jt-new-topic", JtHeaderNewTopic);
});
