import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { settings, themePrefix } from "virtual:theme";
import DiscourseURL from "discourse/lib/url";
import type Site from "discourse/models/site";
import DButton from "discourse/ui-kit/d-button";

// Past this a selection is a passage, not something to look up.
const MAX_TERM = 100;

interface JtSelectionSearchSignature {
  Args: {
    outletArgs: { data?: { quoteState?: { buffer: string } } };
  };
}

// Search in the toolbar over selected text in a post, after core's Quote /
// Edit / Copy (setting selection_search; it replaces the Highlight to Search
// component). Opens the full-page search for the selection.
export default class JtSelectionSearch extends Component<JtSelectionSearchSignature> {
  @service declare site: Site & { can_search: boolean };

  get term() {
    return (this.args.outletArgs.data?.quoteState?.buffer ?? "")
      .replace(/\s+/g, " ")
      .trim();
  }

  get show() {
    return (
      settings.selection_search &&
      this.site.can_search &&
      this.term.length > 0 &&
      this.term.length <= MAX_TERM
    );
  }

  @action
  search() {
    DiscourseURL.routeTo(`/search?q=${encodeURIComponent(this.term)}`, {});
  }

  <template>
    {{#if this.show}}
      <DButton
        class="btn-flat jt-selection-search"
        @action={{this.search}}
        @icon="magnifying-glass"
        @label={{themePrefix "jt.selection_search.label"}}
        @title={{themePrefix "jt.selection_search.title"}}
      />
    {{/if}}
  </template>
}
