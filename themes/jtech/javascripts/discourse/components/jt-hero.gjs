import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { settings } from "virtual:theme";
import { defaultHomepage } from "discourse/lib/utilities";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const DISMISS_KEY = "jt-hero-dismissed";

// Front-page hero: headline, search, quick links. Only on the homepage-style
// discovery routes, never inside a category or tag.
export default class JtHero extends Component {
  @service router;

  @tracked dismissed = this.#readDismissed();
  @tracked term = "";

  get shouldShow() {
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

  get links() {
    return settings.hero_links || [];
  }

  #readDismissed() {
    try {
      return (
        settings.hero_dismissible &&
        window.localStorage.getItem(DISMISS_KEY) === settings.hero_title
      );
    } catch {
      return false;
    }
  }

  @action
  updateTerm(event) {
    this.term = event.target.value;
  }

  @action
  search(event) {
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

  <template>
    {{#if this.shouldShow}}
      <section class="jt-hero" aria-labelledby="jt-hero-title">
        {{#if settings.hero_dismissible}}
          <button
            type="button"
            class="jt-hero__close btn-flat no-text"
            aria-label="Dismiss"
            {{on "click" this.dismiss}}
          >{{dIcon "xmark"}}</button>
        {{/if}}

        <div class="jt-hero__body">
          <div class="jt-hero__copy">
            <h1 id="jt-hero-title" class="jt-hero__title">{{settings.hero_title}}</h1>
            {{#if settings.hero_subtitle}}
              <p class="jt-hero__subtitle">{{settings.hero_subtitle}}</p>
            {{/if}}

            <form class="jt-hero__search" role="search" {{on "submit" this.search}}>
              {{dIcon "magnifying-glass"}}
              <input
                type="search"
                class="jt-hero__input"
                placeholder={{settings.hero_search_placeholder}}
                aria-label={{settings.hero_search_placeholder}}
                value={{this.term}}
                {{on "input" this.updateTerm}}
              />
              <button type="submit" class="jt-hero__go" aria-label="Search">
                {{dIcon "arrow-right"}}
              </button>
            </form>
          </div>

          {{#if this.links.length}}
            <nav class="jt-hero__links" aria-label="Quick links">
              {{#each this.links as |link|}}
                <a class="jt-hero__link" href={{link.url}}>
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
                  <span class="jt-hero__link-arrow">{{dIcon "arrow-right"}}</span>
                </a>
              {{/each}}
            </nav>
          {{/if}}
        </div>
      </section>
    {{/if}}
  </template>
}
