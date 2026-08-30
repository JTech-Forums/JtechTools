import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import icon from "discourse/helpers/d-icon";
import { getURLWithCDN } from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const AVATAR_SIZE = 48;

// WhatsApp-style message info: who has seen the message (read cursor passed
// it) and — for voice notes — who has listened, each with a timestamp.
// Opened by clicking the receipt chip on your own message.
export default class DisteleplusMessageInfo extends Component {
  @service disteleplus;

  get message() {
    return this.args.model.message;
  }

  // Live: recomputed from the service so rows appear while the modal is open.
  get seenBy() {
    return this.disteleplus.seenBy(this.message.id).map((state) => ({
      username: state.username,
      name: state.name || state.username,
      avatarUrl: this.avatar(state.avatar_template),
      at: state.updated_at ? new Date(state.updated_at) : null,
    }));
  }

  get listenedBy() {
    const current =
      this.disteleplus.messages.find((m) => m.id === this.message.id) ||
      this.message;
    return (current.listened_by || []).map((user) => ({
      username: user.username,
      name: user.name || user.username,
      avatarUrl: this.avatar(user.avatar_template),
      at: user.listened_at ? new Date(user.listened_at) : null,
    }));
  }

  get hasVoiceNote() {
    return (this.message.uploads || []).some(
      (upload) => upload.kind === "audio"
    );
  }

  avatar(template) {
    return template
      ? getURLWithCDN(template.replace("{size}", AVATAR_SIZE))
      : null;
  }

  <template>
    <DModal
      @title={{i18n "disteleplus.message_info.title"}}
      @closeModal={{@closeModal}}
      class="disteleplus-message-info"
    >
      <:body>
        <h4>{{icon "check-double"}}
          {{i18n "disteleplus.message_info.seen"}}</h4>
        {{#if this.seenBy.length}}
          <ul class="disteleplus-message-info__list">
            {{#each this.seenBy as |reader|}}
              <li>
                {{#if reader.avatarUrl}}
                  <img src={{reader.avatarUrl}} alt="" />
                {{/if}}
                <span class="disteleplus-message-info__name">
                  {{reader.name}}
                </span>
                {{#if reader.at}}
                  <span class="disteleplus-message-info__when">
                    {{ageWithTooltip reader.at}}
                  </span>
                {{/if}}
              </li>
            {{/each}}
          </ul>
        {{else}}
          <p class="disteleplus-message-info__empty">
            {{i18n "disteleplus.message_info.nobody_yet"}}
          </p>
        {{/if}}

        {{#if this.hasVoiceNote}}
          <h4>{{icon "headphones"}}
            {{i18n "disteleplus.message_info.listened"}}</h4>
          {{#if this.listenedBy.length}}
            <ul class="disteleplus-message-info__list">
              {{#each this.listenedBy as |listener|}}
                <li>
                  {{#if listener.avatarUrl}}
                    <img src={{listener.avatarUrl}} alt="" />
                  {{/if}}
                  <span class="disteleplus-message-info__name">
                    {{listener.name}}
                  </span>
                  {{#if listener.at}}
                    <span class="disteleplus-message-info__when">
                      {{ageWithTooltip listener.at}}
                    </span>
                  {{/if}}
                </li>
              {{/each}}
            </ul>
          {{else}}
            <p class="disteleplus-message-info__empty">
              {{i18n "disteleplus.message_info.nobody_yet"}}
            </p>
          {{/if}}
        {{/if}}
      </:body>
    </DModal>
  </template>
}
