import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import type { ComponentLike } from "@glint/template";
import ComboBoxBase from "select-kit/components/combo-box";
import { settings, themePrefix } from "virtual:theme";
import { i18n } from "discourse-i18n";

type Replies = "all" | "with" | "none";

interface RepliesOption {
  id: Replies;
  name: string;
}

// Select-kit declares ComboBox without a signature.
const ComboBox = ComboBoxBase as unknown as ComponentLike<{
  Args: {
    content: RepliesOption[];
    value: Replies;
    onChange: (value: Replies) => void;
    options?: { caretDownIcon?: string; caretUpIcon?: string };
  };
  Element: HTMLElement;
}>;

// core's own topic-list filters (discovery/list query params)
const PARAMS: Record<Replies, { max_posts?: string; min_posts?: string }> = {
  all: { max_posts: undefined, min_posts: undefined },
  with: { max_posts: undefined, min_posts: "2" },
  none: { max_posts: "1", min_posts: undefined },
};

// A third dropdown beside "categories" and "tags" over a topic list: all
// topics, those with replies, those with none (setting replies_filter; it
// replaces the Unanswered Filter component). Not on the categories page,
// whose lists don't take the filter.
export default class JtRepliesFilter extends Component {
  @service declare router: RouterService;

  get options(): RepliesOption[] {
    return (["all", "with", "none"] as const).map((id) => ({
      id,
      name: i18n(themePrefix(`jt.replies_filter.${id}`)),
    }));
  }

  get show() {
    const route = this.router.currentRouteName ?? "";
    return (
      settings.replies_filter &&
      route.startsWith("discovery.") &&
      route !== "discovery.categories"
    );
  }

  get value(): Replies {
    const params = this.router.currentRoute?.queryParams ?? {};
    if (params.max_posts === "1") {
      return "none";
    }
    return params.min_posts === "2" ? "with" : "all";
  }

  @action
  change(value: Replies) {
    this.router.transitionTo({ queryParams: PARAMS[value] });
  }

  <template>
    {{#if this.show}}
      <li>
        {{! the caret of core's category and tag dropdowns beside it }}
        <ComboBox
          class="jt-replies-filter"
          @content={{this.options}}
          @onChange={{this.change}}
          @options={{hash caretDownIcon="angle-right" caretUpIcon="angle-down"}}
          @value={{this.value}}
        />
      </li>
    {{/if}}
  </template>
}
