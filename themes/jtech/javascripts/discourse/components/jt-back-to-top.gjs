import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// Floating "back to top" once a page is two screens down. Not on topics:
// core's timeline / progress control already jumps to the first post there.
export default class JtBackToTop extends Component {
  @service router;

  @tracked visible = false;

  watchScroll = modifier(() => {
    const update = () => {
      const visible = window.scrollY > window.innerHeight * 2;
      if (visible !== this.visible) {
        this.visible = visible;
      }
    };
    window.addEventListener("scroll", update, { passive: true });
    update();
    return () => window.removeEventListener("scroll", update);
  });

  get onTopic() {
    return this.router.currentRouteName?.startsWith("topic.");
  }

  @action
  toTop() {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" });
  }

  <template>
    {{#unless this.onTopic}}
      <button
        type="button"
        class="jt-to-top btn no-text {{if this.visible '--visible'}}"
        aria-label={{i18n (themePrefix "jt.back_to_top")}}
        title={{i18n (themePrefix "jt.back_to_top")}}
        tabindex={{if this.visible "0" "-1"}}
        {{on "click" this.toTop}}
        {{this.watchScroll}}
      >{{dIcon "arrow-up"}}</button>
    {{/unless}}
  </template>
}
