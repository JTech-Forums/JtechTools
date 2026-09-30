import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { eq, not } from "truth-helpers";
import { KINDS } from "../lib/reqpm-kinds";
import ReqpmKindIcon from "./reqpm-kind-icon";
import ReqpmMethodForm from "./reqpm-method-form";

const isLast = (index, length) => index === length - 1;

// The signed-in user's own contact card: the ways they can be reached, in
// the order they want them shown. Picking "add" shows a grid of platforms
// (phone, WhatsApp, email, … and "Custom" with your own name and emoji);
// picking one opens a small form for just that value.
export default class ReqpmCardEditor extends Component {
  @service reqpm;
  @service dialog;

  @tracked methods = [];
  @tracked max = 10;
  @tracked loading = true;
  // null | "pick" | { kind } | { method }
  @tracked editing = null;

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    try {
      const card = await this.reqpm.card();
      this.methods = card.methods;
      this.max = card.max_methods;
      this.args.onChange?.(card);
      if (this.args.startAdding && this.methods.length === 0) {
        this.editing = "pick";
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  get canAdd() {
    return this.methods.length < this.max;
  }

  get isPicking() {
    return this.editing === "pick";
  }

  // On first run (setup prompt, empty card in the per-user window) the
  // picker is the whole point — there is nothing to go back to.
  get pickerCancellable() {
    return !(this.args.startAdding && this.methods.length === 0);
  }

  get formKind() {
    return this.editing?.kind || null;
  }

  get formMethod() {
    return this.editing?.method || null;
  }

  get kinds() {
    return KINDS.map((k) => ({
      id: k.id,
      name: i18n(`reqpm.kinds.${k.id}.name`),
    }));
  }

  nameFor = (method) =>
    method.kind === "custom"
      ? method.label
      : i18n(`reqpm.kinds.${method.kind}.name`);

  @action
  startAdd() {
    this.editing = "pick";
  }

  @action
  pick(kind) {
    this.editing = { kind };
  }

  @action
  edit(method) {
    this.editing = { method };
  }

  @action
  cancel() {
    this.editing = null;
  }

  @action
  async saved() {
    this.editing = null;
    await this.load();
  }

  @action
  remove(method) {
    this.dialog.deleteConfirm({
      message: i18n("reqpm.editor.delete_confirm", {
        name: this.nameFor(method),
      }),
      didConfirm: async () => {
        try {
          await this.reqpm.deleteMethod(method.id);
          await this.load();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  async move(method, delta) {
    const ids = this.methods.map((m) => m.id);
    const from = ids.indexOf(method.id);
    const to = from + delta;
    if (to < 0 || to >= ids.length) {
      return;
    }
    ids.splice(to, 0, ids.splice(from, 1)[0]);
    try {
      const card = await this.reqpm.reorder(ids);
      this.methods = card.methods;
      this.args.onChange?.(card);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="reqpm-card-editor">
      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.methods.length}}
          <ul class="reqpm-card-editor__list">
            {{#each this.methods as |method index|}}
              <li
                class="reqpm-card-editor__item
                  {{if
                    method.unreadable
                    'reqpm-card-editor__item--unreadable'
                  }}"
              >
                <ReqpmKindIcon @kind={{method.kind}} @emoji={{method.emoji}} />
                <div class="reqpm-card-editor__body">
                  <span class="reqpm-card-editor__name">
                    {{this.nameFor method}}
                    {{#if method.share_by_default}}
                      <span
                        class="reqpm-pill"
                        title={{i18n "reqpm.editor.default_title"}}
                      >{{icon "star"}}
                        {{i18n "reqpm.editor.default_pill"}}</span>
                    {{/if}}
                  </span>
                  {{#if method.unreadable}}
                    <span class="reqpm-card-editor__value">{{i18n
                        "reqpm.editor.unreadable"
                      }}</span>
                  {{else}}
                    <span
                      class="reqpm-card-editor__value"
                    >{{method.value}}</span>
                  {{/if}}
                  {{#if method.note}}
                    <span class="reqpm-card-editor__note">{{method.note}}</span>
                  {{/if}}
                </div>
                <div class="reqpm-card-editor__actions">
                  <DButton
                    @action={{fn this.move method -1}}
                    @icon="chevron-up"
                    @title="reqpm.editor.move_up"
                    @disabled={{eq index 0}}
                    class="btn-flat btn-small"
                  />
                  <DButton
                    @action={{fn this.move method 1}}
                    @icon="chevron-down"
                    @title="reqpm.editor.move_down"
                    @disabled={{isLast index this.methods.length}}
                    class="btn-flat btn-small"
                  />
                  <DButton
                    @action={{fn this.edit method}}
                    @icon="pencil"
                    @title="reqpm.editor.edit"
                    class="btn-flat btn-small"
                  />
                  <DButton
                    @action={{fn this.remove method}}
                    @icon="trash-can"
                    @title="reqpm.editor.delete"
                    class="btn-flat btn-small btn-danger"
                  />
                </div>
                {{#if (eq this.formMethod method)}}
                  <div class="reqpm-card-editor__inline-form">
                    <ReqpmMethodForm
                      @method={{method}}
                      @onSaved={{this.saved}}
                      @onCancel={{this.cancel}}
                    />
                  </div>
                {{/if}}
              </li>
            {{/each}}
          </ul>
        {{else if (not this.editing)}}
          <div class="reqpm-card-editor__empty">
            {{icon "address-card"}}
            <p>{{i18n "reqpm.editor.empty"}}</p>
          </div>
        {{/if}}

        {{#if this.isPicking}}
          <div class="reqpm-card-editor__picker">
            <p class="reqpm-card-editor__picker-title">{{i18n
                "reqpm.editor.pick_title"
              }}</p>
            <div class="reqpm-kind-grid">
              {{#each this.kinds as |kind|}}
                <button
                  type="button"
                  class="reqpm-kind-grid__tile"
                  data-kind={{kind.id}}
                  {{on "click" (fn this.pick kind.id)}}
                >
                  <ReqpmKindIcon @kind={{kind.id}} />
                  <span>{{kind.name}}</span>
                </button>
              {{/each}}
            </div>
            {{#if this.pickerCancellable}}
              <DButton
                @action={{this.cancel}}
                @label="reqpm.form.cancel"
                class="btn-flat"
              />
            {{/if}}
          </div>
        {{else if this.formKind}}
          <div class="reqpm-card-editor__new">
            <ReqpmMethodForm
              @kind={{this.formKind}}
              @onSaved={{this.saved}}
              @onCancel={{this.cancel}}
            />
          </div>
        {{else if this.canAdd}}
          {{#unless this.formMethod}}
            <DButton
              @action={{this.startAdd}}
              @icon="plus"
              @label={{if
                this.methods.length
                "reqpm.editor.add_another"
                "reqpm.editor.add_first"
              }}
              class="btn-primary reqpm-card-editor__add"
            />
          {{/unless}}
        {{else}}
          <p class="reqpm-muted">{{i18n
              "reqpm.editor.limit_reached"
              max=this.max
            }}</p>
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
