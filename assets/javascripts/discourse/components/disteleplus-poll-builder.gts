import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

interface DisteleplusPollBuilderSignature {
  Args: {
    model: { onCreate: (markup: string) => Promise<void> };
    closeModal: () => void;
  };
}

interface CloseChoice {
  key: string;
  hours: number;
}

const CLOSE_CHOICES: CloseChoice[] = [
  { key: "none", hours: 0 },
  { key: "one_hour", hours: 1 },
  { key: "six_hours", hours: 6 },
  { key: "one_day", hours: 24 },
  { key: "three_days", hours: 72 },
  { key: "one_week", hours: 168 },
];

// Builds core [poll] markup from a simple form and hands it back to the
// conversation composer — the server gives the message a backing post so
// the poll runs on core's engine. Templates prefill common shapes.
export default class DisteleplusPollBuilder extends Component<DisteleplusPollBuilderSignature> {
  @tracked question = "";
  @tracked options: string[] = ["", ""];
  @tracked multiple = false;
  @tracked closeHours = 0;
  @tracked sending = false;

  get filledOptions(): string[] {
    return this.options.map((option) => option.trim()).filter(Boolean);
  }

  get disableCreate(): boolean {
    return this.sending || this.filledOptions.length < 2;
  }

  get closeChoices(): (CloseChoice & { label: string; selected: boolean })[] {
    return CLOSE_CHOICES.map((choice) => ({
      ...choice,
      label: i18n(`disteleplus.poll.builder.close_${choice.key}`),
      selected: choice.hours === this.closeHours,
    }));
  }

  @action
  updateQuestion(event: Event) {
    this.question = (event.target as HTMLInputElement).value;
  }

  @action
  updateOption(index: number, event: Event) {
    const next = [...this.options];
    next[index] = (event.target as HTMLInputElement).value;
    this.options = next;
  }

  @action
  addOption() {
    this.options = [...this.options, ""];
  }

  @action
  removeOption(index: number) {
    if (this.options.length <= 2) {
      return;
    }
    this.options = this.options.filter((_, i) => i !== index);
  }

  @action
  toggleMultiple(event: Event) {
    this.multiple = (event.target as HTMLInputElement).checked;
  }

  @action
  updateClose(event: Event) {
    this.closeHours =
      parseInt((event.target as HTMLSelectElement).value, 10) || 0;
  }

  @action
  templateYesNo() {
    this.options = [
      i18n("disteleplus.poll.builder.yes"),
      i18n("disteleplus.poll.builder.no"),
    ];
    this.multiple = false;
  }

  @action
  templateRating() {
    this.options = ["1", "2", "3", "4", "5"];
    this.multiple = false;
  }

  @action
  async create() {
    this.sending = true;
    try {
      const attrs = ["type=" + (this.multiple ? "multiple" : "regular")];
      if (this.multiple) {
        attrs.push("min=1", `max=${this.filledOptions.length}`);
      }
      attrs.push("results=always", "public=true", "chartType=bar");
      if (this.closeHours > 0) {
        const closeAt = new Date(Date.now() + this.closeHours * 3_600_000);
        attrs.push(`close=${closeAt.toISOString()}`);
      }
      const lines = [
        this.question.trim(),
        "",
        `[poll ${attrs.join(" ")}]`,
        ...this.filledOptions.map((option) => `* ${option}`),
        "[/poll]",
      ];
      await this.args.model.onCreate(lines.join("\n").trim());
      this.args.closeModal();
    } finally {
      this.sending = false;
    }
  }

  <template>
    <DModal
      class="disteleplus-poll-builder"
      @closeModal={{@closeModal}}
      @title={{i18n "disteleplus.poll.builder.title"}}
    >
      <:body>
        <div class="disteleplus-poll-builder__templates">
          <button type="button" {{on "click" this.templateYesNo}}>
            {{i18n "disteleplus.poll.builder.template_yes_no"}}
          </button>
          <button type="button" {{on "click" this.templateRating}}>
            {{i18n "disteleplus.poll.builder.template_rating"}}
          </button>
        </div>

        <label class="disteleplus-poll-builder__field">
          {{i18n "disteleplus.poll.builder.question"}}
          <input
            placeholder={{i18n "disteleplus.poll.builder.question_placeholder"}}
            type="text"
            value={{this.question}}
            {{on "input" this.updateQuestion}}
          />
        </label>

        <div class="disteleplus-poll-builder__options">
          <span class="disteleplus-poll-builder__label">
            {{i18n "disteleplus.poll.builder.options"}}
          </span>
          {{#each this.options as |option index|}}
            <div class="disteleplus-poll-builder__option">
              <input
                placeholder={{i18n
                  "disteleplus.poll.builder.option_placeholder"
                }}
                type="text"
                value={{option}}
                {{on "input" (fn this.updateOption index)}}
              />
              <button
                title={{i18n "disteleplus.poll.builder.remove_option"}}
                type="button"
                {{on "click" (fn this.removeOption index)}}
              >
                {{icon "xmark"}}
              </button>
            </div>
          {{/each}}
          <button
            class="disteleplus-poll-builder__add"
            type="button"
            {{on "click" this.addOption}}
          >
            {{icon "plus"}}
            {{i18n "disteleplus.poll.builder.add_option"}}
          </button>
        </div>

        <label class="disteleplus-poll-builder__toggle">
          <input
            checked={{this.multiple}}
            type="checkbox"
            {{on "change" this.toggleMultiple}}
          />
          {{i18n "disteleplus.poll.builder.multiple"}}
        </label>

        <label class="disteleplus-poll-builder__field">
          {{i18n "disteleplus.poll.builder.close_label"}}
          <select {{on "change" this.updateClose}}>
            {{#each this.closeChoices as |choice|}}
              <option selected={{choice.selected}} value={{choice.hours}}>
                {{choice.label}}
              </option>
            {{/each}}
          </select>
        </label>
      </:body>

      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.create}}
          @disabled={{this.disableCreate}}
          @label="disteleplus.poll.builder.create"
        />
        <DButton
          class="btn-flat"
          @action={{@closeModal}}
          @label="disteleplus.cancel"
        />
      </:footer>
    </DModal>
  </template>
}
