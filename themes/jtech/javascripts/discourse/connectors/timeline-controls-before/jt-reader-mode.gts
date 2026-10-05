import Component from "@glimmer/component";
import { action } from "@ember/object";
import { settings, themePrefix } from "virtual:theme";
import DButton from "discourse/ui-kit/d-button";
import { READER_SIZES, READER_WIDTHS, readerMode } from "../../lib/jt-reader";

// Reader mode's switch at the top of the timeline (where the component had
// it), and while it's on, its text size, column width and type.
export default class JtReaderMode extends Component {
  reader = readerMode;

  get show() {
    return settings.reader_mode;
  }

  get smallest() {
    return this.reader.size === 0;
  }

  get largest() {
    return this.reader.size === READER_SIZES.length - 1;
  }

  get narrowest() {
    return this.reader.width === 0;
  }

  get widest() {
    return this.reader.width === READER_WIDTHS.length - 1;
  }

  @action
  toggle() {
    this.reader.toggle();
  }

  @action
  smaller() {
    this.reader.step("size", -1);
  }

  @action
  larger() {
    this.reader.step("size", 1);
  }

  @action
  narrower() {
    this.reader.step("width", -1);
  }

  @action
  wider() {
    this.reader.step("width", 1);
  }

  @action
  serif() {
    this.reader.toggleSerif();
  }

  <template>
    {{#if this.show}}
      <div class="jt-reader-controls">
        <DButton
          aria-pressed={{if this.reader.on "true" "false"}}
          class="btn-flat jt-reader-toggle {{if this.reader.on '--on'}}"
          @action={{this.toggle}}
          @icon="book-open"
          @title={{themePrefix "jt.reader.toggle"}}
        />
        {{#if this.reader.on}}
          <div class="jt-reader-options">
            <DButton
              class="btn-flat jt-reader-smaller"
              @action={{this.smaller}}
              @disabled={{this.smallest}}
              @icon="minus"
              @title={{themePrefix "jt.reader.smaller"}}
            />
            <DButton
              class="btn-flat jt-reader-larger"
              @action={{this.larger}}
              @disabled={{this.largest}}
              @icon="plus"
              @title={{themePrefix "jt.reader.larger"}}
            />
            <DButton
              class="btn-flat jt-reader-narrower"
              @action={{this.narrower}}
              @disabled={{this.narrowest}}
              @icon="down-left-and-up-right-to-center"
              @title={{themePrefix "jt.reader.narrower"}}
            />
            <DButton
              class="btn-flat jt-reader-wider"
              @action={{this.wider}}
              @disabled={{this.widest}}
              @icon="left-right"
              @title={{themePrefix "jt.reader.wider"}}
            />
            <DButton
              aria-pressed={{if this.reader.serif "true" "false"}}
              class="btn-flat jt-reader-serif {{if this.reader.serif '--on'}}"
              @action={{this.serif}}
              @icon="font"
              @title={{themePrefix "jt.reader.serif"}}
            />
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
