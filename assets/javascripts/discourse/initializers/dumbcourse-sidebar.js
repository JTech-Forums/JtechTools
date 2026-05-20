import { apiInitializer } from "discourse/lib/api";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings?.dumbcourse_enabled) {
    return;
  }
  if (!siteSettings?.dumbcourse_sidebar_link_enabled) {
    return;
  }

  const basePath = (siteSettings?.dumbcourse_base_path || "dumb").replace(
    /^\/+|\/+$/g,
    ""
  );

  api.addSidebarSection(
    (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
      class DumbcourseLink extends BaseCustomSidebarSectionLink {
        name = "dumbcourse";
        classNames = "raw-link";
        text = i18n("dumbcourse.sidebar_link_text");
        title = i18n("dumbcourse.sidebar_link_title");
        href = getURL(`/${basePath || "dumb"}`);
        prefixType = "icon";
        prefixValue = "mobile-screen-button";
      }

      return class DumbcourseSection extends BaseCustomSidebarSection {
        name = "dumbcourse";
        text = i18n("dumbcourse.sidebar_section_title");
        title = i18n("dumbcourse.sidebar_section_title");
        hideSectionHeader = true;

        get links() {
          return [new DumbcourseLink()];
        }
      };
    }
  );
});
