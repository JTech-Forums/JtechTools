import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { cook } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import {
  topicFooterFeatureActive,
  topicFooterMessage,
} from "../../lib/topic-footer-message";

// Renders the moderator-curated content at the end of the post stream,
// above the reply button:
//   - a post a moderator pinned to the bottom, shown as a regular-looking
//     post (avatar, username, content) with a pin badge and a button
//     linking up to the original post, and/or
//   - the moderator-set `mod_topic_footer_message`.
//
// `shouldRender` is static and only gates on things that cannot change
// while the page is open. The visible content is held in tracked state
// and refreshed on the `discourse-mod:messages-updated` appEvent fired by
// the moderator edit UIs, so changes appear immediately without a reload.
//
// Discourse reuses this connector instance across topic navigation, so the
// tracked state is also re-read whenever the topic id changes (via a
// `{{did-update}}` modifier) — otherwise the previous topic's footer would
// stay stuck on the new topic.
export default class TopicFooterMessage extends Component {
  static shouldRender(args, context, owner) {
    const siteSettings =
      owner?.lookup("service:site-settings") || context?.siteSettings;
    return topicFooterFeatureActive(siteSettings, args?.model);
  }

  @service appEvents;

  @tracked footerMessage = topicFooterMessage(this.topic);
  @tracked pinnedPostId = this.topic?.mod_topic_pinned_post_id || null;
  @tracked cookedFooterMessage = null;

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "discourse-mod:messages-updated",
      this,
      this.refreshFromTopic
    );
    this.cookFooterMessage();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "discourse-mod:messages-updated",
      this,
      this.refreshFromTopic
    );
  }

  get topic() {
    return this.args.outletArgs.model;
  }

  // appEvent handler for live edits within the current topic. The guard
  // keeps a stale event for another topic from clobbering this one.
  refreshFromTopic(topic) {
    if (!topic || topic.id !== this.topic?.id) {
      return;
    }
    this.readTopicState(topic);
  }

  // Re-read all per-topic state from the current topic. Called on initial
  // insert and whenever the connector is reused for a different topic.
  @action
  refreshOnNavigation() {
    this.readTopicState(this.topic);
  }

  readTopicState(topic) {
    this.footerMessage = topicFooterMessage(topic);
    this.pinnedPostId = topic?.mod_topic_pinned_post_id || null;
    this.cookFooterMessage();
  }

  // Cooks the raw moderator markdown into HTML asynchronously and stores
  // the result in tracked state. The stored/edited value stays raw — only
  // the display is cooked.
  async cookFooterMessage() {
    const raw = this.footerMessage;
    if (!raw) {
      this.cookedFooterMessage = null;
      return;
    }
    const cooked = await cook(raw);
    if (this.footerMessage === raw) {
      this.cookedFooterMessage = cooked;
    }
  }

  get messageHtml() {
    return this.cookedFooterMessage;
  }

  get pinnedPost() {
    if (!this.pinnedPostId) {
      return null;
    }
    return (
      this.topic?.postStream?.posts?.find((p) => p.id === this.pinnedPostId) ||
      null
    );
  }

  // The bottom copy is skipped when the pinned post is already the last
  // post of the topic — the in-stream pin badge is enough in that case.
  get showPinnedCopy() {
    const post = this.pinnedPost;
    if (!post) {
      return false;
    }
    const highest = this.topic?.highest_post_number;
    return !highest || post.post_number !== highest;
  }

  get pinnedPostHtml() {
    return this.pinnedPost ? trustHTML(this.pinnedPost.cooked) : null;
  }

  get pinnedAvatarUrl() {
    const template = this.pinnedPost?.avatar_template;
    return template ? template.replace("{size}", "45") : null;
  }

  get originalPostUrl() {
    const topic = this.topic;
    const post = this.pinnedPost;
    if (!topic || !post) {
      return null;
    }
    return `${topic.url}/${post.post_number}`;
  }

  <template>
    <div
      class="mod-topic-footer-message-outlet"
      {{didInsert this.refreshOnNavigation}}
      {{didUpdate this.refreshOnNavigation this.topic.id}}
    >
      {{#if this.showPinnedCopy}}
        <div class="topic-footer-pinned-post">
          <article class="pinned-post">
            {{#if this.pinnedAvatarUrl}}
              <img
                class="pinned-post-avatar"
                src={{this.pinnedAvatarUrl}}
                width="45"
                height="45"
                alt=""
              />
            {{/if}}
            <div class="pinned-post-main">
              <div class="pinned-post-header">
                <span class="pinned-post-username">
                  {{this.pinnedPost.username}}
                </span>
                <span
                  class="pinned-post-badge"
                  title={{i18n
                    "discourse_mod_categories.pin_post.pinned_label"
                  }}
                >
                  {{icon "thumbtack"}}
                  {{i18n "discourse_mod_categories.pin_post.pinned_label"}}
                </span>
                {{#if this.originalPostUrl}}
                  <a
                    class="pinned-post-jump"
                    href={{this.originalPostUrl}}
                    title={{i18n
                      "discourse_mod_categories.pin_post.jump_to_original"
                    }}
                  >
                    {{icon "arrow-up"}}
                  </a>
                {{/if}}
              </div>
              <div class="cooked">{{this.pinnedPostHtml}}</div>
            </div>
          </article>
        </div>
      {{/if}}
      {{#if this.footerMessage}}
        <div class="topic-footer-message">
          <div class="topic-footer-message-icon">
            {{icon "shield-halved"}}
          </div>
          <div class="topic-footer-message-body">
            <div class="topic-footer-message-label">
              {{i18n "discourse_mod_categories.footer_message.label"}}
            </div>
            <div class="topic-footer-message-content cooked">
              {{this.messageHtml}}
            </div>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
