import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { emojiUrlFor } from "discourse/lib/text";
import { CUSTOM, kindInfo } from "../lib/reqpm-kinds";

// Round badge for a contact kind: the platform's icon, or the emoji the
// user picked for a custom one.
export default class ReqpmKindIcon extends Component {
  get info() {
    return kindInfo(this.args.kind);
  }

  get emojiUrl() {
    if (this.args.kind !== CUSTOM || !this.args.emoji) {
      return null;
    }
    return emojiUrlFor(this.args.emoji);
  }

  <template>
    <span
      class="reqpm-kind-icon reqpm-kind-icon--{{this.info.id}}"
      aria-hidden="true"
    >
      {{#if this.emojiUrl}}
        <img src={{this.emojiUrl}} alt="" class="emoji" />
      {{else}}
        {{icon this.info.icon}}
      {{/if}}
    </span>
  </template>
}
