import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import { themePrefix } from "virtual:theme";
import { ajax } from "discourse/lib/ajax";
import { gt } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

// First post of a topic in a modal. Fetches the post alone (not /t/:id.json)
// so previewing doesn't count as a visit or change the topic's new/unread
// state. Cooked HTML goes through DDecoratedHtml so registered decorators
// (lightbox, spoilers, external-link marks…) run like they do in the stream.
export default class JtQuickLook extends Component {
  @tracked post = null;
  @tracked failed = false;

  constructor() {
    super(...arguments);
    this.load();
  }

  get topic() {
    return this.args.model.topic;
  }

  get cooked() {
    return trustHTML(this.post?.cooked || "");
  }

  async load() {
    try {
      this.post = await ajax(`/posts/by_number/${this.topic.id}/1.json`);
    } catch {
      this.failed = true;
    }
  }

  <template>
    <DModal
      class="jt-quick-look"
      @title={{this.topic.title}}
      @closeModal={{@closeModal}}
    >
      <:belowModalTitle>
        <div class="jt-quick-look__category">{{categoryLinkHTML
            this.topic.category
          }}</div>
      </:belowModalTitle>
      <:body>
        {{#if this.failed}}
          <p class="jt-quick-look__error">{{i18n
              (themePrefix "jt.quick_look_error")
            }}</p>
        {{else}}
          <DConditionalLoadingSpinner @condition={{if this.post false true}}>
            <div class="jt-quick-look__author">
              {{dAvatar this.post imageSize="small"}}
              <span class="jt-quick-look__name">{{this.post.username}}</span>
              <span class="jt-quick-look__date">{{dFormatDate
                  this.post.created_at
                  format="medium"
                }}</span>
            </div>
            <DDecoratedHtml
              @html={{this.cooked}}
              @className="cooked jt-quick-look__cooked"
            />
          </DConditionalLoadingSpinner>
        {{/if}}
      </:body>
      <:footer>
        <a
          class="btn btn-primary"
          href={{this.topic.url}}
          {{on "click" @closeModal}}
        >{{i18n (themePrefix "jt.open_topic")}}</a>
        {{#if (gt this.topic.replyCount 0)}}
          <a
            class="btn btn-default"
            href={{this.topic.lastPostUrl}}
            {{on "click" @closeModal}}
          >{{i18n (themePrefix "jt.latest_reply")}}</a>
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
