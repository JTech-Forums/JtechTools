import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import EmojiPicker from "discourse/components/emoji-picker";
import { i18n } from "discourse-i18n";
import { not } from "truth-helpers";
import { CUSTOM, kindInfo } from "../lib/reqpm-kinds";
import { reqpmError } from "../services/reqpm";
import ReqpmKindIcon from "./reqpm-kind-icon";

// Add or edit one way to reach you. The input adapts to the kind (a phone
// keypad for numbers, email keyboard for email, …); custom ones also get a
// name and an emoji. The server does the real validation and its message is
// shown next to the field it is about.
export default class ReqpmMethodForm extends Component {
  @service reqpm;

  @tracked value = this.args.method?.value || "";
  @tracked label = this.args.method?.label || "";
  @tracked emoji = this.args.method?.emoji || "wave";
  @tracked note = this.args.method?.note || "";
  @tracked shareByDefault = this.args.method
    ? this.args.method.share_by_default
    : true;
  @tracked saving = false;
  @tracked error = null;
  @tracked errorField = null;

  get kind() {
    return this.args.method?.kind || this.args.kind;
  }

  get info() {
    return kindInfo(this.kind);
  }

  get isCustom() {
    return this.kind === CUSTOM;
  }

  get kindName() {
    return i18n(`reqpm.kinds.${this.kind}.name`);
  }

  get fieldLabel() {
    return i18n(`reqpm.kinds.${this.kind}.field`);
  }

  get placeholder() {
    return i18n(`reqpm.kinds.${this.kind}.placeholder`);
  }

  get hint() {
    return i18n(`reqpm.kinds.${this.kind}.hint`);
  }

  get canSave() {
    return (
      !this.saving &&
      this.value.trim().length > 0 &&
      (!this.isCustom || this.label.trim().length > 0)
    );
  }

  get isEdit() {
    return !!this.args.method;
  }

  fieldClass = (field) =>
    this.errorField === field
      ? "reqpm-field reqpm-field--error"
      : "reqpm-field";

  @action
  setValue(event) {
    this.value = event.target.value;
  }

  @action
  setLabel(event) {
    this.label = event.target.value;
  }

  @action
  setNote(event) {
    this.note = event.target.value;
  }

  @action
  setEmoji(emoji) {
    this.emoji = emoji;
  }

  @action
  toggleDefault(event) {
    this.shareByDefault = event.target.checked;
  }

  @action
  async save(event) {
    event?.preventDefault();
    if (!this.canSave) {
      return;
    }
    this.saving = true;
    this.error = null;
    this.errorField = null;

    const attrs = {
      kind: this.kind,
      value: this.value.trim(),
      note: this.note.trim(),
      share_by_default: this.shareByDefault,
    };
    if (this.isCustom) {
      attrs.label = this.label.trim();
      attrs.emoji = this.emoji;
    }

    try {
      const result = this.isEdit
        ? await this.reqpm.updateMethod(this.args.method.id, attrs)
        : await this.reqpm.addMethod(attrs);
      this.args.onSaved?.(result.method);
    } catch (e) {
      const { message, field } = reqpmError(e);
      this.error = message || i18n("reqpm.errors.generic");
      this.errorField = field || "value";
    } finally {
      this.saving = false;
    }
  }

  <template>
    <form class="reqpm-method-form" {{on "submit" this.save}}>
      <div class="reqpm-method-form__head">
        <ReqpmKindIcon @kind={{this.kind}} @emoji={{this.emoji}} />
        <span class="reqpm-method-form__kind">{{this.kindName}}</span>
      </div>

      {{#if this.isCustom}}
        <div class="reqpm-method-form__row">
          <div class={{this.fieldClass "emoji"}}>
            <span class="reqpm-field__label">{{i18n "reqpm.form.emoji"}}</span>
            <EmojiPicker
              @emoji={{this.emoji}}
              @didSelectEmoji={{this.setEmoji}}
              @btnClass="btn-default reqpm-method-form__emoji"
              @context="reqpm"
              @modalForMobile={{true}}
            />
          </div>
          <label class="{{this.fieldClass 'label'}} reqpm-field--grow">
            <span class="reqpm-field__label">{{i18n "reqpm.form.label"}}</span>
            <input
              type="text"
              value={{this.label}}
              maxlength="30"
              placeholder={{i18n "reqpm.form.label_placeholder"}}
              {{on "input" this.setLabel}}
            />
          </label>
        </div>
      {{/if}}

      <label class={{this.fieldClass "value"}}>
        <span class="reqpm-field__label">{{this.fieldLabel}}</span>
        <input
          type={{this.info.input}}
          value={{this.value}}
          inputmode={{this.info.inputmode}}
          autocomplete="off"
          maxlength="200"
          placeholder={{this.placeholder}}
          class="reqpm-method-form__value"
          {{on "input" this.setValue}}
        />
        <span class="reqpm-field__hint">{{this.hint}}</span>
      </label>

      <label class={{this.fieldClass "note"}}>
        <span class="reqpm-field__label">{{i18n "reqpm.form.note"}}
          <span class="reqpm-field__optional">{{i18n
              "reqpm.form.optional"
            }}</span></span>
        <input
          type="text"
          value={{this.note}}
          maxlength="80"
          placeholder={{i18n "reqpm.form.note_placeholder"}}
          {{on "input" this.setNote}}
        />
      </label>

      <label class="reqpm-method-form__default">
        <input
          type="checkbox"
          checked={{this.shareByDefault}}
          {{on "change" this.toggleDefault}}
        />
        {{i18n "reqpm.form.share_by_default"}}
      </label>

      {{#if this.error}}
        <div class="reqpm-method-form__error" role="alert">{{this.error}}</div>
      {{/if}}

      <div class="reqpm-method-form__buttons">
        <DButton
          @action={{this.save}}
          @label={{if this.isEdit "reqpm.form.save" "reqpm.form.add"}}
          @icon="check"
          @disabled={{not this.canSave}}
          @isLoading={{this.saving}}
          class="btn-primary btn-small"
        />
        <DButton
          @action={{@onCancel}}
          @label="reqpm.form.cancel"
          class="btn-flat btn-small"
        />
      </div>
    </form>
  </template>
}
