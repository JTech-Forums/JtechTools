import Component from "@glimmer/component";
import { settings } from "virtual:theme";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";

// What core sends for each badge in post_badges (the theme modifier
// serialize_post_user_badges, see about.json), as post.userBadges.
interface PostBadge {
  id: number;
  name: string;
  slug: string;
  icon?: string;
  image_url?: string;
}

interface JtPostBadgesSignature {
  Args: { outletArgs: { post: { userBadges?: PostBadge[] } } };
}

// The badges listed in post_badges after a poster's name, in the setting's
// order, each linking to its badge page (setting post_badges; it replaces
// the Post Badges component). Core only sends the listed ones, so this only
// orders them. Core's own poster-name icons can't show a badge's image.
export default class JtPostBadges extends Component<JtPostBadgesSignature> {
  // template helpers: arrow functions, so they keep `this`
  href = (badge: PostBadge) => getURL(`/badges/${badge.id}/${badge.slug}`);
  icon = (badge: PostBadge) => (badge.icon ?? "").replace(/^fa-/, "");

  get badges() {
    const order = settings.post_badges
      .split("|")
      .map((name) => name.trim().toLowerCase())
      .filter(Boolean);
    const rank = (badge: PostBadge) => order.indexOf(badge.name.toLowerCase());
    return (this.args.outletArgs.post.userBadges ?? [])
      .filter((badge) => badge && rank(badge) >= 0)
      .sort((a, b) => rank(a) - rank(b));
  }

  <template>
    {{#if this.badges.length}}
      <span class="jt-post-badges">
        {{#each this.badges key="id" as |badge|}}
          <a
            aria-label={{badge.name}}
            class="jt-post-badge"
            href={{this.href badge}}
            title={{badge.name}}
          >
            {{#if badge.image_url}}
              <img alt="" loading="lazy" src={{badge.image_url}} />
            {{else if badge.icon}}
              {{dIcon (this.icon badge)}}
            {{/if}}
          </a>
        {{/each}}
      </span>
    {{/if}}
  </template>
}
