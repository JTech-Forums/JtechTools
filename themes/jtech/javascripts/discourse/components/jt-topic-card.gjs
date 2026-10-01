import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { settings, themePrefix } from "virtual:theme";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicExcerpt from "discourse/components/topic-list/topic-excerpt";
import TopicLink from "discourse/components/topic-list/topic-link";
import UnreadIndicator from "discourse/components/topic-list/unread-indicator";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import lazyHash from "discourse/helpers/lazy-hash";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import JtQuickLook from "./jt-quick-look";

// One topic as a card: meta row, title, excerpt, people + stats footer.
// Rendered as the only cell of the row (see api-initializers/jt-topic-cards).
export default class JtTopicCard extends Component {
  @service currentUser;
  @service modal;

  get topic() {
    return this.args.topic;
  }

  get hasSolved() {
    return this.topic.has_accepted_answer || this.topic.accepted_answer;
  }

  get hasTags() {
    return this.topic.tags?.length > 0;
  }

  get hasExcerpt() {
    return this.topic.excerpt || this.topic.hasExcerpt;
  }

  get posters() {
    return (this.topic.featuredUsers || []).filter((p) => !p.moreCount);
  }

  get hasReplies() {
    return this.topic.replyCount > 0;
  }

  get hasLikes() {
    return this.topic.like_count > 0;
  }

  // The topic's first image: the smallest generated size that is still sharp
  // at 2x (about.json asks core for 320px), else the original.
  get thumbnail() {
    if (!settings.card_thumbnails) {
      return null;
    }
    const sizes = [...(this.topic.thumbnails || [])].sort(
      (a, b) => a.width - b.width
    );
    const pick = sizes.find((t) => t.width >= 240) || sizes.at(-1);
    return pick?.url || this.topic.image_url || null;
  }

  // Signed-in only: the forum's "Gated Topics" component blurs topics for
  // visitors, and Quick look would hand them the whole first post.
  get showQuickLook() {
    return settings.quick_look && this.currentUser;
  }

  @action
  quickLook(event) {
    // keep the row's click-to-open from firing
    event.preventDefault();
    event.stopPropagation();
    this.modal.show(JtQuickLook, { model: { topic: this.topic } });
  }

  @action
  onTitleFocus(event) {
    event.target.closest(".topic-list-item")?.classList.add("selected");
  }

  @action
  onTitleBlur(event) {
    event.target.closest(".topic-list-item")?.classList.remove("selected");
  }

  <template>
    <td class="jt-card">
      <div class="jt-card__meta">
        {{#unless @hideCategory}}
          <span class="jt-card__category">{{categoryLinkHTML
              @topic.category
            }}</span>
        {{/unless}}
        {{#if this.hasTags}}
          {{dDiscourseTags @topic mode="list" className="jt-card__tags"}}
        {{/if}}
        <span class="jt-card__flags">
          {{#if this.hasSolved}}
            <span class="jt-pill --solved">
              {{dIcon "check"}}
              {{i18n (themePrefix "jt.solved")}}
            </span>
          {{/if}}
          {{#if @topic.pinned}}
            <span class="jt-pill">
              {{dIcon "thumbtack"}}
              {{i18n (themePrefix "jt.pinned")}}
            </span>
          {{/if}}
          {{#if @topic.is_hot}}
            <span class="jt-pill">
              {{dIcon "fire"}}
              {{i18n (themePrefix "jt.hot")}}
            </span>
          {{/if}}
        </span>
      </div>

      <div class="jt-card__body">
        <div class="jt-card__text">
          <div aria-level="2" class="jt-card__title" role="heading">
            <TopicStatus @context="topic-list" @topic={{@topic}} />
            <TopicLink
              class="raw-link raw-topic-link"
              @topic={{@topic}}
              {{on "focus" this.onTitleFocus}}
              {{on "blur" this.onTitleBlur}}
            />
            <PluginOutlet
              @name="topic-list-after-title"
              @outletArgs={{lazyHash topic=@topic}}
            />
            <UnreadIndicator @topic={{@topic}} />
            <TopicPostBadges
              @unreadPosts={{@topic.unread_posts}}
              @unseen={{@topic.unseen}}
              @url={{@topic.lastUnreadUrl}}
            />
          </div>

          {{#if this.hasExcerpt}}
            <TopicExcerpt class="jt-card__excerpt" @topic={{@topic}} />
          {{/if}}
        </div>

        {{#if this.thumbnail}}
          <img
            alt=""
            class="jt-card__thumb"
            decoding="async"
            loading="lazy"
            src={{this.thumbnail}}
          />
        {{/if}}
      </div>

      <div class="jt-card__foot">
        <span class="jt-card__people">
          {{#each this.posters as |poster|}}
            {{dAvatar
              poster
              avatarTemplatePath="user.avatar_template"
              usernamePath="user.username"
              namePath="user.name"
              imageSize="small"
            }}
          {{/each}}
        </span>

        <span class="jt-card__stats">
          {{#if this.hasReplies}}
            <span
              class="jt-card__stat"
              title={{i18n (themePrefix "jt.replies") count=@topic.replyCount}}
            >
              {{dIcon "far-comment"}}
              {{dNumber @topic.replyCount}}
            </span>
          {{/if}}
          <span
            class="jt-card__stat"
            title={{i18n (themePrefix "jt.views") count=@topic.views}}
          >
            {{dIcon "far-eye"}}
            {{dNumber @topic.views}}
          </span>
          {{#if this.hasLikes}}
            <span
              class="jt-card__stat"
              title={{i18n (themePrefix "jt.likes") count=@topic.like_count}}
            >
              {{dIcon "far-heart"}}
              {{dNumber @topic.like_count}}
            </span>
          {{/if}}
          {{#if this.showQuickLook}}
            <button
              aria-label={{i18n (themePrefix "jt.quick_look")}}
              class="btn btn-flat no-text jt-card__peek"
              title={{i18n (themePrefix "jt.quick_look")}}
              type="button"
              {{on "click" this.quickLook}}
            >{{dIcon "expand"}}</button>
          {{/if}}
          <span class="jt-card__stat --activity">
            {{dFormatDate @topic.bumpedAt format="tiny"}}
          </span>
        </span>
      </div>
    </td>
  </template>
}
