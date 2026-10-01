import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { themePrefix } from "virtual:theme";
import DiscourseURL from "discourse/lib/url";
import type Topic from "discourse/models/topic";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

interface JtJumpButtonsSignature {
  Args: {
    topic: Topic;
    className: string;
  };
}

// First / last post buttons under the timeline (desktop) and beside the
// progress button (phones). Same navigation as core's own jumpTop / jumpEnd.
export default class JtJumpButtons extends Component<JtJumpButtonsSignature> {
  @action
  top(event: MouseEvent) {
    event.preventDefault();
    DiscourseURL.routeTo(this.args.topic.firstPostUrl, {
      skipIfOnScreen: false,
      keepFilter: true,
    });
  }

  @action
  bottom(event: MouseEvent) {
    event.preventDefault();
    DiscourseURL.routeTo(this.args.topic.lastPostUrl, {
      jumpEnd: true,
      keepFilter: true,
    });
  }

  <template>
    <div class="jt-jump {{@className}}">
      <button
        aria-label={{i18n (themePrefix "jt.jump.top")}}
        class="btn btn-default no-text jt-jump__top"
        title={{i18n (themePrefix "jt.jump.top")}}
        type="button"
        {{on "click" this.top}}
      >{{dIcon "arrow-up"}}</button>
      <button
        aria-label={{i18n (themePrefix "jt.jump.bottom")}}
        class="btn btn-default no-text jt-jump__bottom"
        title={{i18n (themePrefix "jt.jump.bottom")}}
        type="button"
        {{on "click" this.bottom}}
      >{{dIcon "arrow-down"}}</button>
    </div>
  </template>
}
