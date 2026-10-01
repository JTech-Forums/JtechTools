import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";

// The Category Boxes component (shared with Default) shows two letters ("Gc")
// in a tile when a category has no uploaded logo. Put the category's own icon
// / emoji / colour square in that tile instead. Renders into the tile with
// in-element; anywhere else this outlet appears (core titles already carry
// the icon in their badge) it renders nothing.
export default class JtCategoryIcon extends Component {
  @tracked tile = null;

  findTile = modifier((marker) => {
    const tile = marker
      .closest(".custom-category-boxes .category-box-inner")
      ?.querySelector(":scope > .category-logo.no-logo-present");
    if (tile !== this.tile) {
      this.tile = tile || null;
    }
  });

  get category() {
    return this.args.outletArgs.category;
  }

  get styleType() {
    return this.category?.style_type;
  }

  get squareStyle() {
    return trustHTML(`background-color: #${this.category?.color}`);
  }

  <template>
    <span hidden {{this.findTile}}></span>
    {{#if this.tile}}
      {{#in-element this.tile insertBefore=null}}
        <span class="jt-cat-icon" aria-hidden="true">
          {{#if (eq this.styleType "icon")}}
            {{dIcon this.category.icon}}
          {{else if (eq this.styleType "emoji")}}
            {{dEmoji this.category.emoji}}
          {{else}}
            <span class="jt-cat-icon__square" style={{this.squareStyle}}></span>
          {{/if}}
        </span>
      {{/in-element}}
    {{/if}}
  </template>
}
