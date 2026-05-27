import Component from "@glimmer/component";
import { action, get } from "@ember/object";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

// Renders a pill above the composer body whenever a whisper is armed. The
// pill's DOM presence ALSO triggers the tint on the surrounding composer
// fields, via `.composer-fields:has(...)` in SCSS.
//
// An armed whisper with zero targets is a staff-only whisper-back; the pill
// still shows (it is the signal a whisper is armed at all).
export default class ModWhisperArmedPill extends Component {
  get composer() {
    return this.args.outletArgs?.model;
  }

  // `modWhisperArmed` / `modWhisperTargetUsernames` are set on the composer
  // model with Ember's `set`. They are not @tracked native fields, so they
  // must be READ with Ember's `get` — that consumes the classic property tag
  // that `set` dirties. A plain dotted access would never re-render the pill.
  //
  // The boolean armed flag — not the target list — is the signal. An armed
  // whisper with zero targets is a staff-only whisper-back; the pill must
  // still show for it.
  get armed() {
    const composer = this.composer;
    if (!composer) {
      return false;
    }
    return get(composer, "modWhisperArmed") === true;
  }

  get staffOnly() {
    return (
      this.usernames.length === 0 &&
      this.groupNames.length === 0 &&
      this.badges.length === 0
    );
  }

  get usernames() {
    const composer = this.composer;
    return composer ? get(composer, "modWhisperTargetUsernames") || [] : [];
  }

  get groupNames() {
    const composer = this.composer;
    return composer ? get(composer, "modWhisperTargetGroupNames") || [] : [];
  }

  // A separator is needed before a group entry whenever anything (a user, or
  // an earlier group) was already rendered ahead of it.
  @action
  needsSep(groupIndex) {
    return this.usernames.length > 0 || groupIndex > 0;
  }

  get badges() {
    const composer = this.composer;
    return composer ? get(composer, "modWhisperTargetBadges") || [] : [];
  }

  @action
  needsBadgeSep(badgeIndex) {
    return (
      this.usernames.length > 0 || this.groupNames.length > 0 || badgeIndex > 0
    );
  }

  @action
  clearArmed() {
    const composer = this.composer;
    if (!composer) {
      return;
    }
    composer.set("modWhisperArmed", false);
    composer.set("modWhisperTargetUserIds", null);
    composer.set("modWhisperTargetUsernames", null);
    composer.set("modWhisperTargets", null);
    composer.set("modWhisperTargetGroupIds", null);
    composer.set("modWhisperTargetGroupNames", null);
    composer.set("modWhisperTargetGroups", null);
    composer.set("modWhisperTargetBadgeIds", null);
    composer.set("modWhisperTargetBadges", null);
  }

  <template>
    {{#if this.armed}}
      <div class="mod-whisper-armed-pill" role="status">
        {{#if this.staffOnly}}
          <span class="mod-whisper-armed-pill__label">
            {{i18n "discourse_mod_categories.whisper.armed_pill_staff_only"}}
          </span>
        {{else}}
          <span class="mod-whisper-armed-pill__label">
            {{i18n "discourse_mod_categories.whisper.armed_pill_prefix"}}
          </span>
          <span class="mod-whisper-armed-pill__users">
            {{#each this.usernames as |name index|}}
              {{#if index}}<span class="mod-whisper-armed-pill__sep">,
                </span>{{/if}}<span
                class="mod-whisper-armed-pill__user"
              >@{{name}}</span>
            {{/each}}
            {{#each this.groupNames as |name index|}}
              {{#if (this.needsSep index)}}<span
                  class="mod-whisper-armed-pill__sep"
                >, </span>{{/if}}<span
                class="mod-whisper-armed-pill__group"
              >{{name}}</span>
            {{/each}}
            {{#each this.badges as |badge index|}}
              {{#if (this.needsBadgeSep index)}}<span
                  class="mod-whisper-armed-pill__sep"
                >, </span>{{/if}}<span
                class="mod-whisper-armed-pill__badge"
              >{{badge.name}}</span>
            {{/each}}
          </span>
        {{/if}}
        <DButton
          @action={{this.clearArmed}}
          @icon="xmark"
          @title="discourse_mod_categories.whisper.clear_armed"
          class="btn-flat mod-whisper-armed-pill__close"
        />
      </div>
    {{/if}}
  </template>
}
