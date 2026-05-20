import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { i18n } from "discourse-i18n";

// Staff-facing modal (opened from a whisper post's admin menu) for adding a
// user to the topic's whisper conversation. POSTs each chosen username to the
// plugin's whisper-participant endpoint, which merges the user id into the
// topic's cumulative `mod_whisper_participant_ids`.
export default class ModWhisperAddParticipantModal extends Component {
  @service toasts;

  @tracked selection = [];
  @tracked saving = false;

  @action
  updateSelection(usernames) {
    this.selection = usernames;
  }

  @action
  async confirm() {
    const topicId = this.args.model?.post?.topic_id;
    if (!topicId || !this.selection.length) {
      this.args.closeModal();
      return;
    }

    this.saving = true;
    try {
      for (const username of this.selection) {
        await ajax(
          `/discourse-mod-categories/topic/${topicId}/whisper-participant`,
          {
            type: "POST",
            data: { username },
          }
        );
      }

      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n(
            "discourse_mod_categories.whisper.add_participant.added_toast",
            { count: this.selection.length }
          ),
        },
      });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n
        "discourse_mod_categories.whisper.add_participant.modal_title"
      }}
      @closeModal={{@closeModal}}
      class="mod-whisper-add-participant-modal"
    >
      <:body>
        <p class="mod-whisper-add-participant-modal__instructions">
          {{i18n
            "discourse_mod_categories.whisper.add_participant.modal_instructions"
          }}
        </p>
        <EmailGroupUserChooser
          @value={{this.selection}}
          @onChange={{this.updateSelection}}
          @options={{hash
            maximum=10
            filterPlaceholder="discourse_mod_categories.whisper.add_participant.search_placeholder"
          }}
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.confirm}}
          @label="discourse_mod_categories.whisper.add_participant.confirm"
          @disabled={{this.saving}}
          class="btn-primary mod-whisper-add-participant-confirm"
        />
        <DButton
          @action={{@closeModal}}
          @label="discourse_mod_categories.whisper.add_participant.cancel"
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
