import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { settings } from "virtual:theme";
import type User from "discourse/models/user";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

type LastSeenUser = User & { last_seen_at?: string | null };

interface JtLastSeenSignature {
  Args: { outletArgs: { user: LastSeenUser } };
}

// "Seen 3h" on user cards. Core leaves last_seen_at out for people who hide
// their profile and presence, so that preference is respected.
const JtLastSeen: TemplateOnlyComponent<JtLastSeenSignature> = <template>
  {{#if settings.user_card_last_seen}}
    {{#if @outletArgs.user.last_seen_at}}
      <span class="jt-last-seen">
        <span class="desc">{{i18n "user.last_seen"}}</span>
        {{dFormatDate @outletArgs.user.last_seen_at leaveAgo="true"}}
      </span>
    {{/if}}
  {{/if}}
</template>;

export default JtLastSeen;
