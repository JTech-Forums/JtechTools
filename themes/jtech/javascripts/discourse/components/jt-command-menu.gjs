import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { themePrefix } from "virtual:theme";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const t = (key, opts) => i18n(themePrefix(`jt.cmdk.${key}`), opts);

const LIMITS = { commands: 5, categories: 4, topics: 6, users: 3 };

// ⌘K / Ctrl+K: jump to pages, categories, topics and people, or run an
// action, from anywhere. Opened by api-initializers/jt-command-menu.
export default class JtCommandMenu extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;
  @service composer;
  @service interfaceColor;
  @service keyboardShortcuts;

  @tracked query = "";
  @tracked selected = 0;
  @tracked results = null; // /search/query response for `resultsFor`
  @tracked resultsFor = "";
  @tracked loading = false;

  focusInput = modifier((el) => {
    el.focus();
  });

  keepInView = modifier((el, [isSelected]) => {
    if (isSelected) {
      el.scrollIntoView({ block: "nearest" });
    }
  });

  get commands() {
    const user = this.currentUser;
    const list = [
      user && {
        icon: "plus",
        label: t("new_topic"),
        keywords: "create post write",
        run: () => this.composer.openNewTopic({}),
      },
      { icon: "list", label: t("latest"), url: "/latest" },
      user && { icon: "bolt", label: t("new"), url: "/new" },
      user && { icon: "circle-dot", label: t("unread"), url: "/unread" },
      { icon: "arrow-trend-up", label: t("top"), url: "/top" },
      { icon: "layer-group", label: t("categories"), url: "/categories" },
      { icon: "tag", label: t("tags"), url: "/tags" },
      user && {
        icon: "bookmark",
        label: t("bookmarks"),
        url: "/my/activity/bookmarks",
      },
      user && { icon: "envelope", label: t("messages"), url: "/my/messages" },
      user && {
        icon: "bell",
        label: t("notifications"),
        url: "/my/notifications",
      },
      user && { icon: "user", label: t("profile"), url: "/my/summary" },
      user && {
        icon: "gear",
        label: t("preferences"),
        keywords: "settings account",
        url: "/my/preferences",
      },
      this.interfaceColor.selectorAvailable && {
        icon: "circle-half-stroke",
        label: t("toggle_theme"),
        keywords: "dark light mode appearance color",
        run: () => this.toggleTheme(),
      },
      {
        icon: "keyboard",
        label: t("shortcuts"),
        keywords: "keys hotkeys help",
        run: () => this.keyboardShortcuts.showHelpModal(),
      },
      // Only on lists that offer it (core's header button, hidden on cards)
      document.querySelector("button.bulk-select") && {
        icon: "list-check",
        label: t("bulk_select"),
        keywords: "select multiple topics bulk",
        run: () => document.querySelector("button.bulk-select")?.click(),
      },
      user?.staff && { icon: "wrench", label: t("admin"), url: "/admin" },
    ];
    return list.filter(Boolean).map((c) => ({ ...c, group: "commands" }));
  }

  get term() {
    return this.query.trim().toLowerCase();
  }

  // Prefix matches first, then word starts, then anywhere.
  rank(text, extra = "") {
    const hay = text.toLowerCase();
    const term = this.term;
    if (hay.startsWith(term)) {
      return 0;
    }
    if (hay.includes(` ${term}`)) {
      return 1;
    }
    if (hay.includes(term) || extra.toLowerCase().includes(term)) {
      return 2;
    }
    return null;
  }

  filtered(items, textOf, extraOf = () => "") {
    if (!this.term) {
      return items;
    }
    return items
      .map((item) => ({ item, r: this.rank(textOf(item), extraOf(item)) }))
      .filter(({ r }) => r !== null)
      .sort((a, b) => a.r - b.r)
      .map(({ item }) => item);
  }

  // Categories load lazily on this forum, so the client only knows some of
  // them: match the loaded ones instantly, then add the server's matches.
  get categoryItems() {
    if (!this.term) {
      return [];
    }
    const seen = new Set();
    const loaded = this.filtered(
      this.site.categories || [],
      (c) => c.name,
      (c) => c.parentCategory?.name || ""
    );
    const remote = this.resultsFor === this.term ? this.results?.categories || [] : [];
    const items = [];
    for (const c of [...loaded, ...remote]) {
      if (seen.has(c.id) || items.length >= LIMITS.categories) {
        continue;
      }
      seen.add(c.id);
      const parentId = c.parentCategory?.id ?? c.parent_category_id;
      const parent = parentId ? Category.findById(parentId) : null;
      items.push({
        group: "categories",
        icon: "folder",
        label: parent ? `${parent.name} / ${c.name}` : c.name,
        url: c.url || `/c/${c.slug}/${c.id}`,
      });
    }
    return items;
  }

  get searchItems() {
    if (!this.results || this.resultsFor !== this.term) {
      return [];
    }
    const topics = (this.results.topics || [])
      .slice(0, LIMITS.topics)
      .map((topic) => ({
        group: "topics",
        icon: "far-comment",
        label: topic.title,
        hint: Category.findById(topic.category_id)?.name,
        url: `/t/${topic.slug}/${topic.id}`,
      }));
    const users = (this.results.users || [])
      .slice(0, LIMITS.users)
      .map((user) => ({
        group: "users",
        user,
        label: user.username,
        hint: user.name !== user.username ? user.name : null,
        url: `/u/${user.username}`,
      }));
    return [...topics, ...users];
  }

  get fullSearchItem() {
    if (!this.term) {
      return [];
    }
    return [
      {
        group: "search",
        icon: "magnifying-glass",
        label: t("search_for", { term: this.query.trim() }),
        url: `/search?q=${encodeURIComponent(this.query.trim())}`,
      },
    ];
  }

  get items() {
    const commands = this.filtered(
      this.commands,
      (c) => c.label,
      (c) => c.keywords || ""
    ).slice(0, this.term ? LIMITS.commands : undefined);
    const all = [
      ...commands,
      ...this.categoryItems,
      ...this.searchItems,
      ...this.fullSearchItem,
    ];
    return all.map((item, index) => ({ ...item, index }));
  }

  get groups() {
    const groups = [];
    for (const item of this.items) {
      let group = groups.at(-1);
      if (group?.key !== item.group) {
        group = {
          key: item.group,
          label: item.group === "search" ? null : t(`group_${item.group}`),
          items: [],
        };
        groups.push(group);
      }
      group.items.push(item);
    }
    return groups;
  }

  get showLoading() {
    return this.loading && !this.searchItems.length;
  }

  get activeId() {
    return `jt-cmdk-item-${this.selected}`;
  }

  @action
  onInput(event) {
    this.query = event.target.value;
    this.selected = 0;
    const min = this.siteSettings.min_search_term_length || 3;
    if (this.term.length >= min) {
      this.loading = true;
      discourseDebounce(this, this.search, this.term, 200);
    } else {
      this.loading = false;
    }
  }

  async search(term) {
    if (term !== this.term) {
      return;
    }
    try {
      const results = await ajax("/search/query", {
        data: { term, include_blurbs: false },
      });
      const ids = [
        ...(results.topics || []).map((topic) => topic.category_id),
        ...(results.categories || []).map((c) => c.parent_category_id),
      ].filter(Boolean);
      await Category.asyncFindByIds([...new Set(ids)]).catch(() => {});
      if (term === this.term && !this.isDestroying) {
        this.results = results;
        this.resultsFor = term;
      }
    } catch {
      // network/search errors: commands and categories still work
    } finally {
      if (term === this.term && !this.isDestroying) {
        this.loading = false;
      }
    }
  }

  @action
  onKeydown(event) {
    const count = this.items.length;
    if (event.key === "ArrowDown" || (event.key === "n" && event.ctrlKey)) {
      event.preventDefault();
      this.selected = count ? (this.selected + 1) % count : 0;
    } else if (event.key === "ArrowUp" || (event.key === "p" && event.ctrlKey)) {
      event.preventDefault();
      this.selected = count ? (this.selected - 1 + count) % count : 0;
    } else if (event.key === "Enter") {
      event.preventDefault();
      const item = this.items[this.selected];
      if (item) {
        this.run(item, event);
      }
    }
  }

  @action
  hover(index) {
    this.selected = index;
  }

  @action
  run(item, event) {
    const newTab = event?.metaKey || event?.ctrlKey;
    if (item.url && newTab) {
      window.open(item.url, "_blank", "noopener");
      return;
    }
    this.args.closeModal();
    if (item.run) {
      item.run();
    } else if (item.url) {
      DiscourseURL.routeTo(item.url);
    }
  }

  toggleTheme() {
    const dark = this.interfaceColor.colorModeIsDark
      ? true
      : this.interfaceColor.colorModeIsLight
        ? false
        : window.matchMedia("(prefers-color-scheme: dark)").matches;
    if (dark) {
      this.interfaceColor.forceLightMode();
    } else {
      this.interfaceColor.forceDarkMode();
    }
  }

  isSelected = (index) => index === this.selected;

  <template>
    <DModal
      class="jt-cmdk"
      @hideHeader={{true}}
      @closeModal={{@closeModal}}
      @bodyClass="jt-cmdk__body"
    >
      <div class="jt-cmdk__search">
        {{dIcon "magnifying-glass"}}
        <input
          class="jt-cmdk__input"
          type="text"
          role="combobox"
          aria-expanded="true"
          aria-controls="jt-cmdk-list"
          aria-activedescendant={{this.activeId}}
          aria-label={{t "placeholder"}}
          placeholder={{t "placeholder"}}
          autocomplete="off"
          spellcheck="false"
          value={{this.query}}
          {{on "input" this.onInput}}
          {{on "keydown" this.onKeydown}}
          {{this.focusInput}}
        />
        <kbd class="jt-cmdk__esc">esc</kbd>
      </div>

      <div class="jt-cmdk__list" id="jt-cmdk-list" role="listbox">
        {{#each this.groups as |group|}}
          <div class="jt-cmdk__group" role="group" aria-label={{group.label}}>
            {{#if group.label}}
              <div class="jt-cmdk__group-label">{{group.label}}</div>
            {{/if}}
            {{#each group.items as |item|}}
              <button
                type="button"
                id="jt-cmdk-item-{{item.index}}"
                role="option"
                aria-selected={{if (this.isSelected item.index) "true" "false"}}
                class="jt-cmdk__item {{if (this.isSelected item.index) '--active'}}"
                tabindex="-1"
                {{on "click" (fn this.run item)}}
                {{on "mousemove" (fn this.hover item.index)}}
                {{this.keepInView (this.isSelected item.index)}}
              >
                <span class="jt-cmdk__icon">
                  {{#if item.user}}
                    {{dAvatar item.user imageSize="tiny"}}
                  {{else}}
                    {{dIcon item.icon}}
                  {{/if}}
                </span>
                <span class="jt-cmdk__label">{{item.label}}</span>
                {{#if item.hint}}
                  <span class="jt-cmdk__hint">{{item.hint}}</span>
                {{/if}}
                <span class="jt-cmdk__enter" aria-hidden="true">↵</span>
              </button>
            {{/each}}
          </div>
        {{/each}}

        {{#if this.showLoading}}
          <div class="jt-cmdk__status">{{t "searching"}}</div>
        {{/if}}
      </div>

      <div class="jt-cmdk__foot" aria-hidden="true">
        <span><kbd>↑</kbd><kbd>↓</kbd> {{t "navigate"}}</span>
        <span><kbd>↵</kbd> {{t "open"}}</span>
        <span><kbd>ctrl</kbd><kbd>↵</kbd> {{t "new_tab"}}</span>
      </div>
    </DModal>
  </template>
}
