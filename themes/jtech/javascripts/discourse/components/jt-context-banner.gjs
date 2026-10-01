import Component from "@glimmer/component";
import { settings, themePrefix } from "virtual:theme";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

// Header for category and tag pages: tile, breadcrumb, name, description,
// counts. Reads only fields the category/tag models already carry.
export default class JtContextBanner extends Component {
  get category() {
    return settings.category_banners ? this.args.category : null;
  }

  get tag() {
    return !this.args.category && settings.tag_banners ? this.args.tag : null;
  }

  get logoUrl() {
    return this.category?.uploaded_logo?.url;
  }

  get initials() {
    const words = (this.category?.displayName || "").split(/\s+/).filter(Boolean);
    const s =
      words.length > 1 ? words[0][0] + words[1][0] : (words[0] || "").slice(0, 2);
    return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
  }

  get subcategoryCount() {
    return this.category?.subcategories?.length || 0;
  }

  <template>
    {{#if this.category}}
      <section
        class="jt-banner {{if this.logoUrl '--has-logo'}}"
        aria-labelledby="jt-banner-title"
      >
        <span class="jt-banner__tile" aria-hidden="true">
          {{#if this.logoUrl}}
            <img src={{this.logoUrl}} alt="" />
          {{else if this.category.icon}}
            {{dIcon this.category.icon}}
          {{else if this.category.emoji}}
            {{dEmoji this.category.emoji}}
          {{else}}
            {{this.initials}}
          {{/if}}
        </span>
        <div class="jt-banner__body">
          {{#if this.category.parentCategory}}
            <a
              class="jt-banner__parent"
              href={{this.category.parentCategory.url}}
            >{{this.category.parentCategory.displayName}}</a>
          {{/if}}
          <h2 id="jt-banner-title" class="jt-banner__title">
            {{this.category.displayName}}
          </h2>
          {{#if this.category.description_text}}
            <p class="jt-banner__desc">{{this.category.description_text}}</p>
          {{/if}}
          <div class="jt-banner__stats">
            <span>{{dNumber this.category.totalTopicCount}}
              {{i18n
                (themePrefix "jt.topics_label")
                count=this.category.totalTopicCount
              }}</span>
            {{#if this.subcategoryCount}}
              <span>{{this.subcategoryCount}}
                {{i18n
                  (themePrefix "jt.subcategories_label")
                  count=this.subcategoryCount
                }}</span>
            {{/if}}
          </div>
        </div>
      </section>
    {{else if this.tag}}
      <section class="jt-banner --tag" aria-labelledby="jt-banner-title">
        <span class="jt-banner__tile" aria-hidden="true">#</span>
        <div class="jt-banner__body">
          <span class="jt-banner__parent">{{i18n (themePrefix "jt.tag")}}</span>
          <h2 id="jt-banner-title" class="jt-banner__title">
            {{this.tag.name}}
          </h2>
          {{#if this.tag.description}}
            <p class="jt-banner__desc">{{this.tag.description}}</p>
          {{/if}}
          {{#if this.tag.topic_count}}
            <div class="jt-banner__stats">
              <span>{{dNumber this.tag.topic_count}}
                {{i18n
                  (themePrefix "jt.topics_label")
                  count=this.tag.topic_count
                }}</span>
            </div>
          {{/if}}
        </div>
      </section>
    {{/if}}
  </template>
}
