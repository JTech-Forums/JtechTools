import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { eq } from "truth-helpers";
import { KINDS } from "../lib/reqpm-kinds";
import { reqpmError } from "../services/reqpm";
import ReqpmCardEditor from "./reqpm-card-editor";
import ReqpmContactList from "./reqpm-contact-list";
import ReqpmKindIcon from "./reqpm-kind-icon";

const isEmpty = (list) => !list || list.length === 0;
const joinList = (list) => list.join(", ");

function shortDate(value) {
  if (!value) {
    return "";
  }
  return new Date(value).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// The REQ-PM window for one other member, opened from their user card or
// profile, or from a notification. Everything between the two of you in one
// place: what they sent you, asking for their details, and choosing which of
// your own details they may see.
export default class ReqpmUserModal extends Component {
  @service reqpm;
  @service dialog;
  @service router;
  @service currentUser;

  @tracked data = null;
  @tracked loading = true;
  @tracked busy = false;
  @tracked selected = [];
  @tracked wanted = [];
  @tracked notice = null;
  @tracked requestError = null;
  @tracked shareError = null;

  constructor() {
    super(...arguments);
    this.load();
  }

  get username() {
    return this.args.model.user.username;
  }

  async load() {
    try {
      this.apply(await this.reqpm.relationship(this.username));
    } catch (e) {
      popupAjaxError(e);
      this.args.closeModal();
    } finally {
      this.loading = false;
    }
  }

  apply(data) {
    this.data = data;
    this.selected = this.initialSelection(data);
  }

  // Already shared → exactly that. Answering a request → what they asked
  // for, when you have it. Otherwise → your "send by default" ones.
  initialSelection(data) {
    const mine = data.my_methods.filter((m) => !m.unreadable);
    if (data.my_shared_method_ids.length) {
      return [...data.my_shared_method_ids];
    }
    const wanted = data.incoming_request?.wanted_kinds || [];
    if (wanted.length) {
      const matching = mine.filter((m) => wanted.includes(m.kind));
      if (matching.length) {
        return matching.map((m) => m.id);
      }
    }
    return mine.filter((m) => m.share_by_default).map((m) => m.id);
  }

  get title() {
    return i18n("reqpm.user_modal.title", { username: this.username });
  }

  get user() {
    return this.data?.user || this.args.model.user;
  }

  get theirMethods() {
    return this.data?.their_methods || [];
  }

  get myMethods() {
    return (this.data?.my_methods || []).filter((m) => !m.unreadable);
  }

  get alreadyShared() {
    return (this.data?.my_shared_method_ids || []).length > 0;
  }

  get outgoing() {
    return this.data?.outgoing_request;
  }

  get requestState() {
    const d = this.data;
    if (!d) {
      return null;
    }
    if (d.can_request) {
      return "can";
    }
    return d.request_blocked;
  }

  get wantedChoices() {
    return KINDS.map((k) => ({
      id: k.id,
      name: i18n(`reqpm.kinds.${k.id}.short`),
      on: this.wanted.includes(k.id),
    }));
  }

  get incomingWanted() {
    return (this.data?.incoming_request?.wanted_kinds || []).map((k) =>
      i18n(`reqpm.kinds.${k}.short`)
    );
  }

  get shareChoices() {
    return this.myMethods.map((m) => ({
      method: m,
      name: m.kind === "custom" ? m.label : i18n(`reqpm.kinds.${m.kind}.name`),
      checked: this.selected.includes(m.id),
    }));
  }

  get shareLabel() {
    return this.alreadyShared
      ? "reqpm.user_modal.update_share"
      : "reqpm.user_modal.send";
  }

  get pendingSince() {
    return shortDate(this.outgoing?.created_at);
  }

  get retryDate() {
    return shortDate(this.data?.retry_at);
  }

  get profileUrl() {
    return getURL(`/u/${this.username}`);
  }

  @action
  toggleWanted(kind) {
    this.wanted = this.wanted.includes(kind)
      ? this.wanted.filter((k) => k !== kind)
      : [...this.wanted, kind];
  }

  @action
  toggleSelected(id, event) {
    this.selected = event.target.checked
      ? [...new Set([...this.selected, id])]
      : this.selected.filter((x) => x !== id);
  }

  @action
  async sendRequest() {
    this.busy = true;
    this.requestError = null;
    try {
      this.apply(await this.reqpm.request(this.username, this.wanted));
      this.notice = i18n("reqpm.user_modal.request_sent", {
        username: this.username,
      });
    } catch (e) {
      this.requestError = reqpmError(e).message || i18n("reqpm.errors.generic");
    } finally {
      this.busy = false;
    }
  }

  @action
  async withdraw() {
    this.busy = true;
    try {
      await this.reqpm.cancelRequest(this.outgoing.id);
      this.notice = null;
      this.apply(await this.reqpm.relationship(this.username));
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.busy = false;
    }
  }

  @action
  async decline() {
    this.busy = true;
    try {
      await this.reqpm.declineRequest(this.data.incoming_request.id);
      this.apply(await this.reqpm.relationship(this.username));
      this.notice = i18n("reqpm.user_modal.declined");
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.busy = false;
    }
  }

  @action
  async share() {
    if (!this.selected.length) {
      return;
    }
    this.busy = true;
    this.shareError = null;
    try {
      this.apply(await this.reqpm.share(this.username, this.selected));
      this.notice = i18n("reqpm.user_modal.shared", {
        username: this.username,
      });
    } catch (e) {
      this.shareError = reqpmError(e).message || i18n("reqpm.errors.generic");
    } finally {
      this.busy = false;
    }
  }

  @action
  stopSharing() {
    this.dialog.yesNoConfirm({
      message: i18n("reqpm.user_modal.stop_confirm", {
        username: this.username,
      }),
      didConfirm: async () => {
        try {
          this.apply(await this.reqpm.revoke(this.username));
          this.notice = i18n("reqpm.user_modal.stopped", {
            username: this.username,
          });
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  forget() {
    this.dialog.yesNoConfirm({
      message: i18n("reqpm.user_modal.forget_confirm", {
        username: this.username,
      }),
      didConfirm: async () => {
        try {
          await this.reqpm.forget(this.username);
          this.apply(await this.reqpm.relationship(this.username));
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  async cardChanged(card) {
    // First method added from inside this window: reload so the picker
    // appears with it pre-ticked.
    if (!card?.methods?.length) {
      return;
    }
    this.reqpm.clearSetupPrompt();
    this.apply(await this.reqpm.relationship(this.username));
  }

  @action
  openHub() {
    this.args.closeModal();
    this.router.transitionTo("preferences.reqpm", this.currentUser.username);
  }

  <template>
    <DModal
      @title={{this.title}}
      @closeModal={{@closeModal}}
      class="reqpm-user-modal"
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.data}}
            <div class="reqpm-user-modal__who">
              <a href={{this.profileUrl}}>{{avatar
                  this.user
                  imageSize="medium"
                }}</a>
              <div>
                <div
                  class="reqpm-user-modal__username"
                >{{this.user.username}}</div>
                {{#if this.user.name}}
                  <div class="reqpm-muted">{{this.user.name}}</div>
                {{/if}}
              </div>
            </div>

            {{#if this.notice}}
              <div class="reqpm-callout reqpm-callout--success" role="status">
                {{icon "check"}}
                <span>{{this.notice}}</span>
              </div>
            {{/if}}

            {{#if this.data.incoming_request}}
              <div class="reqpm-callout reqpm-callout--incoming">
                {{icon "hand"}}
                <div>
                  <strong>{{i18n
                      "reqpm.user_modal.they_asked"
                      username=this.username
                    }}</strong>
                  {{#if this.incomingWanted.length}}
                    <div class="reqpm-muted">{{i18n
                        "reqpm.user_modal.they_would_like"
                        kinds=(joinList this.incomingWanted)
                      }}</div>
                  {{/if}}
                  <div class="reqpm-muted">{{i18n
                      "reqpm.user_modal.they_asked_hint"
                    }}</div>
                  <DButton
                    @action={{this.decline}}
                    @label="reqpm.user_modal.no_thanks"
                    @disabled={{this.busy}}
                    class="btn-flat btn-small reqpm-user-modal__decline"
                  />
                </div>
              </div>
            {{/if}}

            <div
              class="reqpm-user-modal__sections
                {{if
                  this.data.incoming_request
                  'reqpm-user-modal__sections--answering'
                }}"
            >
              <section class="reqpm-section reqpm-section--theirs">
                <h3>{{i18n
                    "reqpm.user_modal.their_details"
                    username=this.username
                  }}</h3>
                {{#if this.theirMethods.length}}
                  <ReqpmContactList @methods={{this.theirMethods}} />
                  <DButton
                    @action={{this.forget}}
                    @label="reqpm.user_modal.forget"
                    class="btn-flat btn-small reqpm-user-modal__forget"
                  />
                {{else}}
                  <p class="reqpm-muted">{{i18n
                      "reqpm.user_modal.nothing_yet"
                      username=this.username
                    }}</p>
                {{/if}}

                {{#if (eq this.requestState "can")}}
                  <div class="reqpm-ask">
                    <p class="reqpm-ask__label">{{i18n
                        "reqpm.user_modal.what_would_you_like"
                      }}</p>
                    <div class="reqpm-chips">
                      {{#each this.wantedChoices as |choice|}}
                        <button
                          type="button"
                          class="reqpm-chip {{if choice.on 'reqpm-chip--on'}}"
                          aria-pressed={{if choice.on "true" "false"}}
                          {{on "click" (fn this.toggleWanted choice.id)}}
                        >
                          <ReqpmKindIcon @kind={{choice.id}} />
                          {{choice.name}}
                        </button>
                      {{/each}}
                    </div>
                    {{#if this.requestError}}
                      <div
                        class="reqpm-error"
                        role="alert"
                      >{{this.requestError}}</div>
                    {{/if}}
                    <DButton
                      @action={{this.sendRequest}}
                      @label="reqpm.user_modal.request"
                      @isLoading={{this.busy}}
                      class="btn-default btn-small reqpm-user-modal__request"
                    />
                  </div>
                {{else if (eq this.requestState "pending")}}
                  <div class="reqpm-status">
                    {{icon "clock"}}
                    <span>{{i18n
                        "reqpm.user_modal.pending"
                        date=this.pendingSince
                        username=this.username
                      }}</span>
                    {{#if this.outgoing.can_cancel}}
                      <DButton
                        @action={{this.withdraw}}
                        @label="reqpm.user_modal.withdraw"
                        @disabled={{this.busy}}
                        class="btn-flat btn-small"
                      />
                    {{/if}}
                  </div>
                {{else if (eq this.requestState "cooldown")}}
                  <div class="reqpm-status">
                    {{icon "clock"}}
                    <span>{{i18n
                        "reqpm.user_modal.cooldown"
                        date=this.retryDate
                      }}</span>
                  </div>
                {{else if (eq this.requestState "unavailable")}}
                  {{#unless this.theirMethods.length}}
                    <div class="reqpm-status">
                      {{icon "user-lock"}}
                      <span>{{i18n
                          "reqpm.user_modal.unavailable"
                          username=this.username
                        }}</span>
                    </div>
                  {{/unless}}
                {{/if}}
              </section>

              <section class="reqpm-section reqpm-section--send">
                <h3>{{i18n "reqpm.user_modal.your_details"}}</h3>
                {{#if this.data.can_share}}
                  {{#if this.myMethods.length}}
                    <p class="reqpm-muted">{{i18n
                        "reqpm.user_modal.pick_hint"
                        username=this.username
                      }}</p>
                    <ul class="reqpm-share-list">
                      {{#each this.shareChoices as |choice|}}
                        <li>
                          <label class="reqpm-share-list__item">
                            <input
                              type="checkbox"
                              checked={{choice.checked}}
                              {{on
                                "change"
                                (fn this.toggleSelected choice.method.id)
                              }}
                            />
                            <ReqpmKindIcon
                              @kind={{choice.method.kind}}
                              @emoji={{choice.method.emoji}}
                            />
                            <span class="reqpm-share-list__text">
                              <span
                                class="reqpm-share-list__name"
                              >{{choice.name}}</span>
                              <span
                                class="reqpm-share-list__value"
                              >{{choice.method.value}}</span>
                            </span>
                          </label>
                        </li>
                      {{/each}}
                    </ul>
                    {{#if this.shareError}}
                      <div
                        class="reqpm-error"
                        role="alert"
                      >{{this.shareError}}</div>
                    {{/if}}
                    <div class="reqpm-user-modal__send-buttons">
                      <DButton
                        @action={{this.share}}
                        @icon="paper-plane"
                        @label={{this.shareLabel}}
                        @disabled={{isEmpty this.selected}}
                        @isLoading={{this.busy}}
                        class="btn-primary btn-small reqpm-user-modal__send"
                      />
                      {{#if this.alreadyShared}}
                        <DButton
                          @action={{this.stopSharing}}
                          @label="reqpm.user_modal.stop_sharing"
                          class="btn-flat btn-danger"
                        />
                      {{/if}}
                    </div>
                    <DButton
                      @action={{this.openHub}}
                      @icon="pencil"
                      @label="reqpm.user_modal.edit_card"
                      class="btn-flat btn-small reqpm-user-modal__edit-card"
                    />
                  {{else}}
                    <p class="reqpm-muted">{{i18n
                        "reqpm.user_modal.no_methods"
                        username=this.username
                      }}</p>
                    <ReqpmCardEditor
                      @startAdding={{true}}
                      @onChange={{this.cardChanged}}
                    />
                  {{/if}}
                {{else}}
                  <div class="reqpm-status">
                    {{icon "user-lock"}}
                    <span>{{i18n
                        "reqpm.user_modal.cannot_share"
                        username=this.username
                      }}</span>
                  </div>
                {{/if}}
              </section>
            </div>
          {{/if}}
        </ConditionalLoadingSpinner>
      </:body>
      <:footer>
        <DButton
          @action={{@closeModal}}
          @label="reqpm.user_modal.close"
          class="btn-default"
        />
      </:footer>
    </DModal>
  </template>
}
