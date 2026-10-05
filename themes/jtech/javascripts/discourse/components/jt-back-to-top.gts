import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

interface JtBackToTopSignature {
  Args: Record<string, never>;
}

// Floating "back to top" once a page is two screens down. Not on topics:
// core's timeline / progress control already jumps to the first post there.
export default class JtBackToTop extends Component<JtBackToTopSignature> {
  @service declare router: RouterService;

  @tracked visible = false;

  watchScroll = modifier(() => {
    const update = () => {
      const visible = window.scrollY > window.innerHeight * 2;
      if (visible !== this.visible) {
        this.visible = visible;
      }
    };
    window.addEventListener("scroll", update, { passive: true });
    // the first look waits for the next frame: reading the scroll position
    // while the page is still rendering forces a layout of a half-built page
    const frame = requestAnimationFrame(update);
    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("scroll", update);
    };
  });

  get onTopic(): boolean {
    return this.router.currentRouteName?.startsWith("topic.");
  }

  @action
  toTop() {
    const reduce = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" });
  }

  <template>
    {{#unless this.onTopic}}
      <button
        aria-hidden={{if this.visible "false" "true"}}
        aria-label={{i18n (themePrefix "jt.back_to_top")}}
        class="jt-to-top btn no-text {{if this.visible '--visible'}}"
        tabindex={{if this.visible "0" "-1"}}
        title={{i18n (themePrefix "jt.back_to_top")}}
        type="button"
        {{on "click" this.toTop}}
        {{this.watchScroll}}
      >{{dIcon "arrow-up"}}</button>
    {{/unless}}
  </template>
}
