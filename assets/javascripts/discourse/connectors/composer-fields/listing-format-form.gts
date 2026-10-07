import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
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
  optional: boolean;
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

  // Opening the composer mustn't bring up the keyboard: on a phone it covers
  // the form, and the editor (the pictures section) isn't where a listing
  // starts. Core focuses the editor as a reply opens, so until the person
  // taps or types in the composer, focus landing in it is dropped. With a
  // mouse there's no keyboard to pop up, so the first box takes focus.
  holdFocus = modifier(() => {
    const control = document.getElementById("reply-control");
    if (!control) {
      return;
    }
    const drop = (event: FocusEvent) => {
      (event.target as HTMLElement | null)?.blur?.();
    };
    const release = () => {
      control.removeEventListener("focusin", drop, true);
      control.removeEventListener("pointerdown", release, true);
      control.removeEventListener("keydown", release, true);
    };
    control.addEventListener("focusin", drop, true);
    control.addEventListener("pointerdown", release, true);
    control.addEventListener("keydown", release, true);

    next(() => {
      const focused = document.activeElement as HTMLElement | null;
      if (focused && control.contains(focused)) {
        focused.blur();
      }
      if (window.matchMedia("(pointer: fine)").matches) {
        release();
        control
          .querySelector<HTMLElement>(".listing-format-form__input")
          ?.focus();
      }
    });
    // Core's focus comes as the composer opens; after that, leave it be.
    const timer = setTimeout(release, 1500);
    return () => {
      clearTimeout(timer);
      release();
    };
  });

  // Ticks aren't tracked (they live on the composer), so a pick bumps this
  // to update the box's hint.
  @tracked picks = 0;

  placeholder = (row: Row): string => {
    void this.picks;
    const needs = this.composer
      ? (row.choice?.details ?? []).filter((option) =>
          this.composer?.listingPicked?.[row.field]?.includes(option)
        )
      : [];
    if (needs.length) {
      return i18n("listing_format.composer.details_needed", {
        options: needs.join(", "),
      });
    }
    return row.choice ? i18n("listing_format.composer.other_details") : "";
  };

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
      optional: setup.optional.includes(field),
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
    this.picks++;
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
      <div class="listing-format-form" {{this.fitComposer}} {{this.holdFocus}}>
        {{#each this.rows as |row|}}
          {{#if row.editor}}
            <p class="listing-format-form__editor-note">
              <span class="listing-format-form__label">{{row.field}}</span>
              {{#if row.optional}}
                <span class="listing-format-form__optional">{{i18n
                    "listing_format.composer.optional"
                  }}</span>
              {{/if}}
              {{i18n "listing_format.composer.in_editor"}}
            </p>
          {{else}}
            <div class="listing-format-form__section">
              <label
                class="listing-format-form__label"
                for={{row.id}}
              >{{row.field}}
                {{#if row.optional}}
                  <span class="listing-format-form__optional">{{i18n
                      "listing_format.composer.optional"
                    }}</span>
                {{/if}}
              </label>
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
                placeholder={{this.placeholder row}}
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
