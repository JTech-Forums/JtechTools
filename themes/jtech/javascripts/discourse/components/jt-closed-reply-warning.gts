import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import type { ComponentLike } from "@glint/template";
import ComposerTipCloseButtonBase from "discourse/components/composer-tip-close-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import type Topic from "discourse/models/topic";
import DButton from "discourse/ui-kit/d-button";

// core's close button for composer notes, untyped in core
const ComposerTipCloseButton =
  ComposerTipCloseButtonBase as unknown as ComponentLike<{
    Args: { action: () => void };
  }>;

type Status = "closed" | "archived";

interface ClosedReplyMessage {
  topic: Topic & {
    closed?: boolean;
    archived?: boolean;
    isPrivateMessage?: boolean;
    details?: { can_close_topic?: boolean; can_archive_topic?: boolean };
  };
  body: string;
}

interface JtClosedReplyWarningSignature {
  Args: {
    message: ClosedReplyMessage;
    closeMessage: (message: ClosedReplyMessage) => void;
  };
}

// The composer note for someone replying where most people can't (see
// api-initializers/jt-closed-reply-warning): reopen or unarchive from here,
// with core's own topic actions, and the note goes once nothing is left.
export default class JtClosedReplyWarning extends Component<JtClosedReplyWarningSignature> {
  @tracked cleared: Status[] = [];

  get topic() {
    return this.args.message.topic;
  }

  get canReopen() {
    return (
      !this.cleared.includes("closed") &&
      !!this.topic.closed &&
      !!this.topic.details?.can_close_topic
    );
  }

  get canUnarchive() {
    return (
      !this.cleared.includes("archived") &&
      !!this.topic.archived &&
      !this.topic.isPrivateMessage &&
      !!this.topic.details?.can_archive_topic
    );
  }

  @action
  reopen() {
    return this.clear("closed");
  }

  @action
  unarchive() {
    return this.clear("archived");
  }

  async clear(status: Status) {
    const topic = this.topic;
    try {
      const result = (await topic.saveStatus(status, false, undefined)) as {
        topic_status_update?: unknown;
      };
      topic.set(status, false);
      topic.set("topic_status_update", result.topic_status_update);
      this.cleared = [...this.cleared, status];
      if (!this.canReopen && !this.canUnarchive) {
        this.args.closeMessage(this.args.message);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <ComposerTipCloseButton @action={{fn @closeMessage @message}} />
    <div class="composer-popup__content jt-closed-reply">
      <p>{{@message.body}}</p>
      {{#if this.canReopen}}
        <DButton
          class="btn-default jt-closed-reply__open"
          @action={{this.reopen}}
          @icon="topic.opened"
          @label="topic.actions.open"
        />
      {{/if}}
      {{#if this.canUnarchive}}
        <DButton
          class="btn-default jt-closed-reply__unarchive"
          @action={{this.unarchive}}
          @icon="folder"
          @label="topic.actions.unarchive"
        />
      {{/if}}
    </div>
  </template>
}
