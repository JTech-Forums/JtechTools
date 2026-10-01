import Component from "@glimmer/component";
import { service } from "@ember/service";
import { settings, themePrefix } from "virtual:theme";
import bodyClass from "discourse/helpers/body-class";
import routeAction from "discourse/helpers/route-action";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import JtechMark from "./jtech-mark";

function listSetting(value) {
  return (value || "").split("|").filter(Boolean);
}

// Logged-out visitors on a topic in a gated category, or with a gated tag, see
// its first lines fade into a prompt to log in or sign up (jt-gate.scss). It
// only hides the topic in the browser: the post is still sent to them.
export default class JtGate extends Component {
  @service currentUser;
  @service siteSettings;

  get topic() {
    return this.args.topic;
  }

  get gated() {
    if (this.currentUser || !this.topic || this.topic.isPrivateMessage) {
      return false;
    }
    const categories = listSetting(settings.gated_categories).map(Number);
    if (categories.includes(this.topic.category_id)) {
      return true;
    }
    const tags = listSetting(settings.gated_tags);
    return (this.topic.tags || []).some((tag) =>
      tags.includes(typeof tag === "string" ? tag : tag?.name)
    );
  }

  get canSignUp() {
    return (
      this.siteSettings.allow_new_registrations &&
      !this.siteSettings.invite_only
    );
  }

  get categoriesURL() {
    return getURL("/categories");
  }

  get description() {
    const category = this.topic.category;
    return category
      ? i18n(themePrefix("jt.gate.description"), { category: category.name })
      : i18n(themePrefix("jt.gate.description_no_category"));
  }

  <template>
    {{#if this.gated}}
      {{bodyClass "jt-gated"}}
      <section aria-labelledby="jt-gate-title" class="jt-gate">
        <div class="jt-gate__card">
          <div aria-hidden="true" class="jt-gate__badge">
            <JtechMark />
            <span class="jt-gate__lock">{{dIcon "lock"}}</span>
          </div>

          {{#if this.topic.category}}
            <div class="jt-gate__category">
              {{categoryLinkHTML this.topic.category}}
            </div>
          {{/if}}

          <h2 class="jt-gate__title" id="jt-gate-title">
            {{i18n (themePrefix "jt.gate.title")}}
          </h2>
          <p class="jt-gate__text">{{this.description}}</p>

          <div class="jt-gate__actions">
            {{#if this.canSignUp}}
              <DButton
                class="btn-primary jt-gate__sign-up"
                @action={{routeAction "showCreateAccount"}}
                @translatedLabel={{i18n (themePrefix "jt.gate.sign_up")}}
              />
            {{/if}}
            <DButton
              class={{if
                this.canSignUp
                "btn-default jt-gate__log-in"
                "btn-primary jt-gate__log-in"
              }}
              @action={{routeAction "showLogin"}}
              @translatedLabel={{i18n (themePrefix "jt.gate.log_in")}}
            />
          </div>

          <a class="jt-gate__browse" href={{this.categoriesURL}}>
            {{i18n (themePrefix "jt.gate.browse")}}
            {{dIcon "arrow-right"}}
          </a>
        </div>
      </section>
    {{/if}}
  </template>
}
