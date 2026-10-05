import type RouterService from "@ember/routing/router-service";
import { settings, themePrefix } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import type User from "discourse/models/user";
import { i18n } from "discourse-i18n";

interface InboxGroup {
  name: string;
  full_name?: string | null;
}

type InboxUser = User & {
  username: string;
  groupsWithMessages?: InboxGroup[];
  sidebarShowCountOfNewItems?: boolean;
};

interface InboxFilter {
  inboxFilter: "user" | "group";
  groupName?: string;
}

interface PmTrackingState {
  lookupCount?: (type: "new" | "unread", filter: InboxFilter) => number;
}

interface InboxLinkOptions {
  name: string;
  text: string;
  route: string;
  models: unknown[];
  icon: string;
  filter: InboxFilter;
}

// An "Inboxes" sidebar section for people in groups with a shared inbox
// (setting sidebar_inboxes; it replaces the Messages section for sidebar
// component): their own messages and each group's, with unread and new
// counts the way core's My Messages shows its total. Everyone else has core's
// My Messages, which this would only repeat.
export default apiInitializer((api) => {
  const user = api.getCurrentUser() as InboxUser | null;
  const groups = user?.groupsWithMessages ?? [];
  if (!settings.sidebar_inboxes || !user || !groups.length) {
    return;
  }
  const pm = api.container.lookup(
    "service:pm-topic-tracking-state"
  ) as PmTrackingState;
  const router = api.container.lookup("service:router") as RouterService;
  const unseen = (filter: InboxFilter) =>
    (pm.lookupCount?.("unread", filter) ?? 0) +
    (pm.lookupCount?.("new", filter) ?? 0);

  api.addSidebarSection(
    (
      BaseCustomSidebarSection: new () => object,
      BaseCustomSidebarSectionLink: new () => object
    ) => {
      class InboxLink extends BaseCustomSidebarSectionLink {
        options: InboxLinkOptions;
        prefixType = "icon";

        constructor(options: InboxLinkOptions) {
          super();
          this.options = options;
        }

        get name() {
          return this.options.name;
        }

        get text() {
          return this.options.text;
        }

        get title() {
          return this.options.text;
        }

        get route() {
          return this.options.route;
        }

        get models() {
          return this.options.models;
        }

        get prefixValue() {
          return this.options.icon;
        }

        get count() {
          return unseen(this.options.filter);
        }

        // a number, or a dot for people who turned counts off (Preferences →
        // Navigation), like core's own sidebar links
        get badgeText() {
          return user?.sidebarShowCountOfNewItems && this.count
            ? String(this.count)
            : undefined;
        }

        get suffixType() {
          return "icon";
        }

        get suffixValue() {
          return !user?.sidebarShowCountOfNewItems && this.count
            ? "circle"
            : undefined;
        }

        get suffixCSSClass() {
          return "unread";
        }
      }

      const links = [
        new InboxLink({
          name: "jt-inbox-personal",
          text: i18n(themePrefix("jt.inboxes.personal")),
          route: "userPrivateMessages.user",
          models: [user],
          icon: "inbox",
          filter: { inboxFilter: "user" },
        }),
        ...groups.map(
          (group) =>
            new InboxLink({
              name: `jt-inbox-${group.name}`,
              text: group.full_name || group.name,
              route: "userPrivateMessages.group",
              models: [user, group.name],
              icon: "users",
              filter: { inboxFilter: "group", groupName: group.name },
            })
        ),
      ];

      return class InboxesSection extends BaseCustomSidebarSection {
        name = "jt-inboxes";
        text = i18n(themePrefix("jt.inboxes.title"));
        actionsIcon = "plus";

        get actions() {
          return [
            {
              id: "jt-new-message",
              title: i18n(themePrefix("jt.inboxes.new_message")),
              action: () => router.transitionTo("new-message"),
            },
          ];
        }

        get links() {
          return links;
        }
      };
    }
  );
});
