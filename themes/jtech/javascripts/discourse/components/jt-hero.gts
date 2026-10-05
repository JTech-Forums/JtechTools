import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { settings, themePrefix } from "virtual:theme";
import routeAction from "discourse/helpers/route-action";
import { defaultHomepage } from "discourse/lib/utilities";
import type Category from "discourse/models/category";
import type Site from "discourse/models/site";
import type Tag from "discourse/models/tag";
import type User from "discourse/models/user";
import type SiteSettings from "discourse/services/site-settings";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import JtPlanet from "../lib/jt-planet";

const DISMISS_KEY = "jt-hero-dismissed";
const SEEN_KEY = "jt-hero-seen";

// One of the bright stars flaring: it swells, turns a quarter and fades
const FLARE: Keyframe[] = [
  { opacity: 0, scale: "0.2", rotate: "0deg" },
  { opacity: 1, scale: "1", rotate: "45deg", offset: 0.5 },
  { opacity: 0, scale: "0.4", rotate: "90deg" },
];

type HeroSite = Site & { can_search: boolean };

interface HeroSiteSettings {
  allow_new_registrations: boolean;
  invite_only: boolean;
}

export interface JtHeroSignature {
  Args: {
    category?: Category | null;
    tag?: Tag | null;
  };
}

function reducedMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function readSession(key: string): string | null {
  try {
    return window.sessionStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeSession(key: string, value: string) {
  try {
    window.sessionStorage.setItem(key, value);
  } catch {
    // storage unavailable: the hero just doesn't remember for this tab
  }
}

// Front-page hero: a planet (lib/jt-planet) beside the headline, search and
// a way in for visitors. Only on the homepage-style discovery routes, never
// inside a category or tag.
export default class JtHero extends Component<JtHeroSignature> {
  @service declare currentUser: User | null;
  @service declare router: RouterService;
  @service declare site: HeroSite;
  @service declare siteSettings: SiteSettings & HeroSiteSettings;

  @tracked dismissed = this.#readDismissed();
  @tracked term = "";
  @tracked searching = false;
  // The first time in this tab the hero arrives (jt-hero.scss); after that
  // it's simply there. Modifiers read an untracked copy (#firstView), or
  // they'd run again (the planet restarting) when the arrival ends.
  @tracked entering = !readSession(SEEN_KEY);

  // The section is on screen: remember it was seen, and let the light and
  // the planet follow a mouse pointer
  arrive = modifier((hero: HTMLElement) => {
    writeSession(SEEN_KEY, "1");
    const settle = setTimeout(() => (this.entering = false), 3600);

    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
      return () => clearTimeout(settle);
    }
    let frame: number | null = null;
    let pointer: PointerEvent | null = null;

    const follow = () => {
      frame = null;
      if (!pointer) {
        return;
      }
      const box = hero.getBoundingClientRect();
      const x = pointer.clientX - box.left;
      const y = pointer.clientY - box.top;
      const nx = (x / box.width) * 2 - 1;
      const ny = (y / box.height) * 2 - 1;
      hero.style.setProperty("--jt-hero-mx", `${Math.round(x)}px`);
      hero.style.setProperty("--jt-hero-my", `${Math.round(y)}px`);
      hero.style.setProperty("--jt-hero-px", nx.toFixed(3));
      hero.style.setProperty("--jt-hero-py", ny.toFixed(3));
      this.#planet?.point(nx, ny);
    };
    const move = (event: PointerEvent) => {
      pointer = event;
      frame ??= requestAnimationFrame(follow);
    };
    const leave = () => {
      pointer = null;
      for (const name of ["--jt-hero-px", "--jt-hero-py"]) {
        hero.style.removeProperty(name);
      }
      this.#planet?.point(0, 0);
    };

    hero.addEventListener("pointermove", move);
    hero.addEventListener("pointerleave", leave);
    return () => {
      clearTimeout(settle);
      hero.removeEventListener("pointermove", move);
      hero.removeEventListener("pointerleave", leave);
      if (frame !== null) {
        cancelAnimationFrame(frame);
      }
    };
  });

  planet = modifier((box: HTMLElement) => {
    const planet = new JtPlanet(box, {
      still: reducedMotion(),
      intro: this.#firstView,
    });
    this.#planet = planet;
    return () => {
      planet.destroy();
      if (this.#planet === planet) {
        this.#planet = null;
      }
    };
  });

  // Every few seconds one of the bright stars flares, in turn, while the
  // hero is on screen. A short animation each time rather than four that
  // never stop: in between, nothing runs.
  flare = modifier((stars: HTMLElement) => {
    if (reducedMotion()) {
      return;
    }
    const sparkles = [
      ...stars.querySelectorAll<HTMLElement>(".jt-hero__sparkle"),
    ];
    let next = 0;
    const timer = setInterval(() => {
      const box = stars.getBoundingClientRect();
      if (document.hidden || box.bottom < 0 || box.top > window.innerHeight) {
        return;
      }
      sparkles[next++ % sparkles.length]?.animate(FLARE, {
        duration: 1600,
        easing: "ease-in-out",
      });
    }, 2300);
    return () => clearInterval(timer);
  });

  #firstView = this.entering;
  #planet: JtPlanet | null = null;

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

  get heroClass(): string {
    return [
      "jt-hero",
      settings.hero_planet && "--planet",
      this.entering && "--enter",
      this.searching && "--searching",
    ]
      .filter(Boolean)
      .join(" ");
  }

  get canSignUp(): boolean {
    return (
      this.siteSettings.allow_new_registrations &&
      !this.siteSettings.invite_only
    );
  }

  @action
  updateTerm(event: Event) {
    this.term = (event.target as HTMLInputElement).value;
    this.#planet?.pulse();
  }

  @action
  focusSearch() {
    this.searching = true;
    this.#planet?.boost(true);
  }

  @action
  blurSearch(event: FocusEvent) {
    const form = event.currentTarget as HTMLElement;
    if (form.contains(event.relatedTarget as Node | null)) {
      return;
    }
    this.searching = false;
    this.#planet?.boost(false);
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
      <section
        aria-labelledby="jt-hero-title"
        class={{this.heroClass}}
        {{this.arrive}}
      >
        <div aria-hidden="true" class="jt-hero__sky">
          <span class="jt-hero__stars" {{this.flare}}>
            <span class="jt-hero__sparkle"></span>
            <span class="jt-hero__sparkle"></span>
            <span class="jt-hero__sparkle"></span>
            <span class="jt-hero__sparkle"></span>
          </span>
          <span class="jt-hero__light"></span>
          <span class="jt-hero__meteor"></span>
          {{#if settings.hero_planet}}
            <span class="jt-hero__planet" {{this.planet}}>
              <canvas data-layer="aura"></canvas>
              <canvas data-layer="back"></canvas>
              <canvas data-layer="dots"></canvas>
              <canvas data-layer="front"></canvas>
            </span>
          {{/if}}
        </div>
        <span aria-hidden="true" class="jt-hero__edge"><span
            class="jt-hero__comet"
          ></span></span>

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
              dir="auto"
              id="jt-hero-title"
            >{{settings.hero_title}}</h1>
            {{#if settings.hero_subtitle}}
              <p
                class="jt-hero__subtitle"
                dir="auto"
              >{{settings.hero_subtitle}}</p>
            {{/if}}

            {{#if this.site.can_search}}
              <form
                class="jt-hero__search"
                role="search"
                {{on "submit" this.search}}
                {{on "focusin" this.focusSearch}}
                {{on "focusout" this.blurSearch}}
              >
                {{dIcon "magnifying-glass"}}
                <input
                  aria-label={{settings.hero_search_placeholder}}
                  class="jt-hero__input"
                  dir="auto"
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

            {{#unless this.currentUser}}
              <div class="jt-hero__actions">
                {{#if this.canSignUp}}
                  <DButton
                    class="btn-primary jt-hero__sign-up"
                    @action={{routeAction "showCreateAccount"}}
                    @label="sign_up"
                  />
                {{/if}}
                <DButton
                  class={{if
                    this.canSignUp
                    "btn-default jt-hero__log-in"
                    "btn-primary jt-hero__log-in"
                  }}
                  @action={{routeAction "showLogin"}}
                  @label="log_in"
                />
              </div>
            {{/unless}}
          </div>
        </div>
      </section>
    {{/if}}
  </template>
}
