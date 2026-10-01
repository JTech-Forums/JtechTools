import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { type JtechThemeLink, settings, themePrefix } from "virtual:theme";
import { defaultHomepage } from "discourse/lib/utilities";
import type Category from "discourse/models/category";
import type Site from "discourse/models/site";
import type Tag from "discourse/models/tag";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { needsFullPageLoad } from "../lib/jt-links";

const DISMISS_KEY = "jt-hero-dismissed";

type HeroSite = Site & { can_search: boolean };

interface HeroLink extends JtechThemeLink {
  fullPage: boolean;
}

export interface JtHeroSignature {
  Args: {
    category?: Category | null;
    tag?: Tag | null;
  };
}

// Front-page hero: headline, search, quick links. Only on the homepage-style
// discovery routes, never inside a category or tag.
export default class JtHero extends Component<JtHeroSignature> {
  @service declare router: RouterService;
  @service declare site: HeroSite;

  @tracked dismissed = this.#readDismissed();
  @tracked term = "";

  get shouldShow(): boolean {
    if (!settings.hero_enabled || this.dismissed) {
      return false;
    }
    if (this.args.category || this.args.tag) {
      return false;
    }
    const routes = [
      `discovery.${defaultHomepage()}`,
      "discovery.latest",
      "discovery.categories",
    ];
    return routes.includes(this.router.currentRouteName);
  }

  get links(): HeroLink[] {
    return (settings.hero_links || []).map((link) => ({
      ...link,
      fullPage: needsFullPageLoad(this.router, link.url),
    }));
  }

  @action
  updateTerm(event: Event) {
    this.term = (event.target as HTMLInputElement).value;
  }

  @action
  search(event: SubmitEvent) {
    event.preventDefault();
    const q = this.term.trim();
    this.router.transitionTo("full-page-search", {
      queryParams: q ? { q } : {},
    });
  }

  @action
  dismiss() {
    this.dismissed = true;
    try {
      // Keyed on the title: changing the headline shows the hero again.
      window.localStorage.setItem(DISMISS_KEY, settings.hero_title);
    } catch {
      // storage unavailable: dismissal lasts for this page view
    }
  }

  #readDismissed(): boolean {
    try {
      return (
        settings.hero_dismissible &&
        window.localStorage.getItem(DISMISS_KEY) === settings.hero_title
      );
    } catch {
      return false;
    }
  }

  <template>
    {{#if this.shouldShow}}
      <section aria-labelledby="jt-hero-title" class="jt-hero">
        {{#if settings.hero_dismissible}}
          <button
            aria-label={{i18n (themePrefix "jt.dismiss")}}
            class="jt-hero__close btn-flat no-text"
            type="button"
            {{on "click" this.dismiss}}
          >{{dIcon "xmark"}}</button>
        {{/if}}

        <div class="jt-hero__body">
          <div class="jt-hero__copy">
            <h1
              class="jt-hero__title"
              id="jt-hero-title"
            >{{settings.hero_title}}</h1>
            {{#if settings.hero_subtitle}}
              <p class="jt-hero__subtitle">{{settings.hero_subtitle}}</p>
            {{/if}}

            {{#if this.site.can_search}}
              <form
                class="jt-hero__search"
                role="search"
                {{on "submit" this.search}}
              >
                {{dIcon "magnifying-glass"}}
                <input
                  aria-label={{settings.hero_search_placeholder}}
                  class="jt-hero__input"
                  placeholder={{settings.hero_search_placeholder}}
                  type="search"
                  value={{this.term}}
                  {{on "input" this.updateTerm}}
                />
                <button
                  aria-label={{i18n (themePrefix "jt.hero.search")}}
                  class="jt-hero__go"
                  type="submit"
                >
                  {{dIcon "arrow-right"}}
                </button>
              </form>
            {{/if}}
          </div>

          {{#if this.links.length}}
            <nav
              aria-label={{i18n (themePrefix "jt.hero.quick_links")}}
              class="jt-hero__links"
            >
              {{#each this.links as |link|}}
                <a
                  class="jt-hero__link"
                  data-auto-route={{if link.fullPage "true"}}
                  href={{link.url}}
                >
                  {{#if link.icon}}
                    <span class="jt-hero__link-icon">{{dIcon link.icon}}</span>
                  {{/if}}
                  <span class="jt-hero__link-text">
                    <span class="jt-hero__link-title">{{link.title}}</span>
                    {{#if link.description}}
                      <span
                        class="jt-hero__link-desc"
                      >{{link.description}}</span>
                    {{/if}}
                  </span>
                  <span class="jt-hero__link-arrow">{{dIcon
                      "arrow-right"
                    }}</span>
                </a>
              {{/each}}
            </nav>
          {{/if}}
        </div>
      </section>
    {{/if}}
  </template>
}
