import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { modifier } from "ember-modifier";
import { i18n } from "discourse-i18n";
import {
  type ListingChoice,
  type ListingComposer,
  type ListingSetup,
  listingSetup,
} from "../../lib/listing-format";

interface ListingFormatFormSignature {
  Args: { outletArgs: { model?: ListingComposer | null } };
}

interface Row {
  field: string;
  id: string;
  choice: ListingChoice | null;
  editor: boolean;
}

// Room the editor, its toolbar and the composer's header and footer need
// under the form.
const EDITOR_ROOM = 300;

// A box per section above the editor when replying in a listing topic, with
// options to pick for sections that have them (condition, pickup/shipping).
// The section names are fixed text, so the format can't be broken by
// editing it; the editor below fills the pictures section.
export default class ListingFormatForm extends Component<ListingFormatFormSignature> {
  // The form sits above the editor inside the composer's fixed height, so
  // a short composer would leave the editor no room and its toolbar over
  // the form. Grow it once to fit, the way dragging its edge would.
  fitComposer = modifier((element: HTMLElement) => {
    const root = document.documentElement;
    const current = parseInt(
      getComputedStyle(root).getPropertyValue("--composer-height"),
      10
    );
    const needed = Math.min(
      element.offsetHeight + EDITOR_ROOM,
      Math.round(window.innerHeight * 0.85)
    );
    if (current && current >= needed) {
      return;
    }
    const height = `${needed}px`;
    this.composer?.set("composerHeight", height);
    root.style.setProperty("--composer-height", height);
  });

  // Start in the form rather than the editor. On phones a focused editor
  // slides up over everything above it, the form included, so focusing it
  // on open (core's default for replies) hid the form.
  focusFirst = modifier((element: HTMLElement) => {
    next(() => element.querySelector<HTMLElement>("textarea, input")?.focus());
  });

  get composer(): ListingComposer | null | undefined {
    return this.args.outletArgs?.model;
  }

  get setup(): ListingSetup | null {
    return this.composer ? listingSetup(this.composer) : null;
  }

  get rows(): Row[] {
    const setup = this.setup;
    if (!setup) {
      return [];
    }
    return setup.fields.map((field) => ({
      field,
      id: `listing-format-${field.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`,
      choice: setup.choices[field] ?? null,
      editor: field === setup.editorField,
    }));
  }

  value = (field: string): string =>
    this.composer?.listingValues?.[field] ?? "";

  isPicked = (field: string, option: string): boolean =>
    this.composer?.listingPicked?.[field]?.includes(option) ?? false;

  optionId = (row: Row, option: string): string =>
    `${row.id}-${option.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`;

  @action
  update(field: string, event: Event) {
    const values = this.composer?.listingValues;
    if (values) {
      values[field] = (event.target as HTMLTextAreaElement).value;
    }
  }

  @action
  pick(row: Row, option: string, event: Event) {
    const picked = this.composer?.listingPicked;
    if (!picked) {
      return;
    }
    const on = (event.target as HTMLInputElement).checked;
    const current = picked[row.field] ?? [];
    if (!row.choice?.multiple) {
      picked[row.field] = on ? [option] : [];
    } else if (on) {
      picked[row.field] = [...current, option];
    } else {
      picked[row.field] = current.filter((o) => o !== option);
    }
  }

  <template>
    {{#if this.rows.length}}
      <div class="listing-format-form" {{this.fitComposer}} {{this.focusFirst}}>
        {{#each this.rows as |row|}}
          {{#if row.editor}}
            <p class="listing-format-form__editor-note">
              <span class="listing-format-form__label">{{row.field}}</span>
              {{i18n "listing_format.composer.in_editor"}}
            </p>
          {{else}}
            <div class="listing-format-form__section">
              <label
                class="listing-format-form__label"
                for={{row.id}}
              >{{row.field}}</label>
              {{#if row.choice}}
                <div
                  class="listing-format-form__options"
                  role={{if row.choice.multiple "group" "radiogroup"}}
                  aria-label={{row.field}}
                >
                  {{#each row.choice.options as |option|}}
                    <label
                      class="listing-format-form__option"
                      for={{this.optionId row option}}
                    >
                      <input
                        id={{this.optionId row option}}
                        type={{if row.choice.multiple "checkbox" "radio"}}
                        name={{row.id}}
                        checked={{this.isPicked row.field option}}
                        {{on "change" (fn this.pick row option)}}
                      />
                      {{option}}
                    </label>
                  {{/each}}
                </div>
              {{/if}}
              <textarea
                id={{row.id}}
                class="listing-format-form__input"
                rows="1"
                placeholder={{if
                  row.choice
                  (i18n "listing_format.composer.other_details")
                }}
                value={{this.value row.field}}
                {{on "input" (fn this.update row.field)}}
              ></textarea>
            </div>
          {{/if}}
        {{/each}}
      </div>
    {{/if}}
  </template>
}
