import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import type ToastsService from "discourse/float-kit/services/toasts";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import type AppEventsService from "discourse/services/app-events";
import { i18n } from "discourse-i18n";

export interface AddParticipantPost {
  id: number;
  topic_id: number;
}

interface ModWhisperAddParticipantModalSignature {
  Args: {
    model: { post: AddParticipantPost };
    closeModal: () => void;
  };
}

// Staff-facing modal (opened from a whisper post's admin menu) for adding
// users to THAT whisper's audience. POSTs each chosen username to the
// plugin's whisper-participant endpoint, which adds the user id to the
// post's explicit targets — never to every whisper in the topic.
export default class ModWhisperAddParticipantModal extends Component<ModWhisperAddParticipantModalSignature> {
  @service declare appEvents: AppEventsService;
  @service declare toasts: ToastsService;

  @tracked selection: string[] = [];
  @tracked saving = false;

  @action
  updateSelection(usernames: string[]) {
    this.selection = usernames;
  }

  @action
  async confirm() {
    const post = this.args.model?.post;
    const topicId = post?.topic_id;
    if (!topicId || !post?.id || !this.selection.length) {
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
            data: { username, post_id: post.id },
          }
        );
      }
      this.appEvents.trigger("post-stream:refresh", { id: post.id });

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
      class="mod-whisper-add-participant-modal"
      @closeModal={{@closeModal}}
      @title={{i18n
        "discourse_mod_categories.whisper.add_participant.modal_title"
      }}
    >
      <:body>
        <EmailGroupUserChooser
          @onChange={{this.updateSelection}}
          @options={{hash
            maximum=10
            filterPlaceholder="discourse_mod_categories.whisper.add_participant.search_placeholder"
          }}
          @value={{this.selection}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary mod-whisper-add-participant-confirm"
          @action={{this.confirm}}
          @disabled={{this.saving}}
          @label="discourse_mod_categories.whisper.add_participant.confirm"
        />
        <DButton
          class="btn-flat"
          @action={{@closeModal}}
          @label="discourse_mod_categories.whisper.add_participant.cancel"
        />
      </:footer>
    </DModal>
  </template>
}
