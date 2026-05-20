import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { i18n } from "discourse-i18n";

// Staff-facing modal (opened from the composer toolbar eye button) for
// picking the users AND groups a whisper reply should be visible to. Writes
// the chosen ids/usernames/group ids/group names/objects onto the composer
// model. The chooser returns a flat array mixing usernames and group names;
// `confirm` resolves each entry to either a user id or a group id.
export default class ModWhisperTargetModal extends Component {
  @tracked selection = this.#initialSelection();
  @tracked saving = false;

  #initialSelection() {
    const composer = this.args.model?.composer;
    const usernames = Array.isArray(composer?.modWhisperTargetUsernames)
      ? composer.modWhisperTargetUsernames
      : [];
    const groupNames = Array.isArray(composer?.modWhisperTargetGroupNames)
      ? composer.modWhisperTargetGroupNames
      : [];
    return [...usernames, ...groupNames];
  }

  @action
  updateSelection(names) {
    this.selection = names;
  }

  @action
  async confirm() {
    const composer = this.args.model?.composer;
    if (!composer) {
      this.args.closeModal();
      return;
    }

    if (!this.selection.length) {
      // An empty selection still ARMS a whisper — a staff-only whisper-back.
      composer.set("modWhisperArmed", true);
      composer.set("modWhisperTargetUserIds", []);
      composer.set("modWhisperTargetUsernames", []);
      composer.set("modWhisperTargets", []);
      composer.set("modWhisperTargetGroupIds", []);
      composer.set("modWhisperTargetGroupNames", []);
      composer.set("modWhisperTargetGroups", []);
      this.args.closeModal();
      return;
    }

    this.saving = true;
    try {
      // Each selected name is EITHER a username OR a group name. Resolve all
      // of them via /groups/<name>.json first; whatever is not a real group
      // is treated as a username and resolved via /u/<name>.json.
      const groupLookups = await Promise.all(
        this.selection.map((name) =>
          ajax(`/groups/${encodeURIComponent(name)}.json`)
            .then((data) => data?.group)
            .catch(() => null)
        )
      );

      const groups = [];
      const remainingUsernames = [];
      this.selection.forEach((name, index) => {
        const group = groupLookups[index];
        if (group?.id) {
          groups.push(group);
        } else {
          remainingUsernames.push(name);
        }
      });

      const userLookups = await Promise.all(
        remainingUsernames.map((username) =>
          ajax(`/u/${encodeURIComponent(username)}.json`)
            .then((data) => data?.user)
            .catch(() => null)
        )
      );
      const users = userLookups.filter(Boolean);

      composer.set("modWhisperArmed", true);
      composer.set(
        "modWhisperTargetUserIds",
        users.map((u) => u.id)
      );
      composer.set(
        "modWhisperTargetUsernames",
        users.map((u) => u.username)
      );
      composer.set(
        "modWhisperTargets",
        users.map((u) => ({
          id: u.id,
          username: u.username,
          avatar_template: u.avatar_template,
        }))
      );

      composer.set(
        "modWhisperTargetGroupIds",
        groups.map((g) => g.id)
      );
      composer.set(
        "modWhisperTargetGroupNames",
        groups.map((g) => g.name)
      );
      composer.set(
        "modWhisperTargetGroups",
        groups.map((g) => ({ id: g.id, name: g.name }))
      );

      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  @action
  clear() {
    const composer = this.args.model?.composer;
    if (composer) {
      composer.set("modWhisperArmed", false);
      composer.set("modWhisperTargetUserIds", null);
      composer.set("modWhisperTargetUsernames", null);
      composer.set("modWhisperTargets", null);
      composer.set("modWhisperTargetGroupIds", null);
      composer.set("modWhisperTargetGroupNames", null);
      composer.set("modWhisperTargetGroups", null);
    }
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "discourse_mod_categories.whisper.modal_title"}}
      @closeModal={{@closeModal}}
      class="mod-whisper-target-modal"
    >
      <:body>
        <p class="mod-whisper-target-modal__instructions">
          {{i18n "discourse_mod_categories.whisper.modal_instructions"}}
        </p>
        <EmailGroupUserChooser
          @value={{this.selection}}
          @onChange={{this.updateSelection}}
          @options={{hash
            maximum=10
            includeGroups=true
            filterPlaceholder="discourse_mod_categories.whisper.search_placeholder"
          }}
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.confirm}}
          @label="discourse_mod_categories.whisper.confirm"
          @disabled={{this.saving}}
          class="btn-primary mod-whisper-confirm"
        />
        <DButton
          @action={{this.clear}}
          @label="discourse_mod_categories.whisper.clear"
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
