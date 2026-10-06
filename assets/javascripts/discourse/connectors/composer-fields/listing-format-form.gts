import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import { type ListingComposer, listingFields } from "../../lib/listing-format";

interface ListingFormatFormSignature {
  Args: { outletArgs: { model?: ListingComposer | null } };
}

// One input per field above the editor when replying in a listing topic.
// The labels are fixed text, so the format can't be broken by editing it;
// the editor below stays free for pictures and details.
export default class ListingFormatForm extends Component<ListingFormatFormSignature> {
  get composer(): ListingComposer | null | undefined {
    return this.args.outletArgs?.model;
  }

  get fields(): string[] {
    return this.composer ? listingFields(this.composer) : [];
  }

  value = (field: string): string =>
    this.composer?.listingValues?.[field] ?? "";

  inputId = (field: string): string =>
    `listing-format-${field.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`;

  @action
  update(field: string, event: Event) {
    const composer = this.composer;
    if (!composer?.listingValues) {
      return;
    }
    composer.listingValues[field] = (event.target as HTMLInputElement).value;
  }

  <template>
    {{#if this.fields.length}}
      <div class="listing-format-form">
        {{#each this.fields as |field|}}
          <div class="listing-format-form__row">
            <label
              class="listing-format-form__label"
              for={{this.inputId field}}
            >{{field}}</label>
            <input
              id={{this.inputId field}}
              class="listing-format-form__input"
              type="text"
              value={{this.value field}}
              aria-required="true"
              {{on "input" (fn this.update field)}}
            />
          </div>
        {{/each}}
        <p class="listing-format-form__hint">
          {{i18n "listing_format.composer.details"}}
        </p>
      </div>
    {{/if}}
  </template>
}
