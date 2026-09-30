import Component from "@glimmer/component";
import DModal from "discourse/components/d-modal";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import icon from "discourse/helpers/d-icon";
import { getURLWithCDN } from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const AVATAR_SIZE = 48;

export interface PostViewer {
  username: string;
  name?: string | null;
  avatar_template?: string | null;
  last_seen_topic_at?: string | null;
}

export interface PostViewersResponse {
  count: number;
  viewers: PostViewer[];
}

interface ViewerRow {
  username: string;
  name: string;
  avatarUrl: string | null;
  at: Date | null;
}

interface ModPostViewersSignature {
  Args: {
    model: PostViewersResponse;
    closeModal: () => void;
  };
}

// Staff-only "who read this post" modal, fed by core's post_timings via
// /discourse-mod-categories/post/:id/viewers. The per-user timestamp is
// their last visit to the topic — the closest thing core stores.
export default class ModPostViewers extends Component<ModPostViewersSignature> {
  get viewers(): ViewerRow[] {
    return (this.args.model.viewers || []).map((viewer) => ({
      username: viewer.username,
      name: viewer.name || viewer.username,
      avatarUrl: viewer.avatar_template
        ? getURLWithCDN(
            viewer.avatar_template.replace("{size}", String(AVATAR_SIZE))
          )
        : null,
      at: viewer.last_seen_topic_at
        ? new Date(viewer.last_seen_topic_at)
        : null,
    }));
  }

  <template>
    <DModal
      class="mod-post-viewers"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_mod_categories.post_viewers.title"}}
    >
      <:body>
        <p class="mod-post-viewers__count">
          {{icon "eye"}}
          {{i18n
            "discourse_mod_categories.post_viewers.count"
            count=@model.count
          }}
        </p>
        {{#if this.viewers.length}}
          <ul class="mod-post-viewers__list">
            {{#each this.viewers as |viewer|}}
              <li>
                {{#if viewer.avatarUrl}}
                  <img alt="" src={{viewer.avatarUrl}} />
                {{/if}}
                <a
                  class="mod-post-viewers__name"
                  data-user-card={{viewer.username}}
                  href="/u/{{viewer.username}}"
                >{{viewer.name}}</a>
                {{#if viewer.at}}
                  <span class="mod-post-viewers__when">
                    {{ageWithTooltip viewer.at}}
                  </span>
                {{/if}}
              </li>
            {{/each}}
          </ul>
        {{else}}
          <p class="mod-post-viewers__empty">
            {{i18n "discourse_mod_categories.post_viewers.nobody"}}
          </p>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
