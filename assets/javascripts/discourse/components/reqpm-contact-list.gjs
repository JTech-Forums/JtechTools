import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { eq } from "truth-helpers";
import { actionFor, isExternal } from "../lib/reqpm-kinds";
import ReqpmKindIcon from "./reqpm-kind-icon";

const GO_ICONS = {
  call: "phone",
  text: "comment-sms",
  chat: "comment-dots",
  email: "envelope",
  visit: "arrow-up-right-from-square",
  open: "arrow-up-right-from-square",
};

// Someone's shared details, each with a one-tap action (call, text, open
// WhatsApp, …) where one makes sense, and a copy button. Values render as
// plain text; the only links are the fixed-scheme ones from actionFor.
export default class ReqpmContactList extends Component {
  @service toasts;

  @tracked copiedId = null;

  get rows() {
    return (this.args.methods || []).map((method) => {
      const go = actionFor(method);
      return {
        method,
        name:
          method.kind === "custom"
            ? method.label
            : i18n(`reqpm.kinds.${method.kind}.name`),
        go,
        goLabel: go ? i18n(`reqpm.actions.${go.label}`) : null,
        goIcon: go ? GO_ICONS[go.label] : null,
        external: go ? isExternal(go.href) : false,
      };
    });
  }

  @action
  copy(method) {
    clipboardCopy(method.value);
    this.copiedId = method.id;
    this.toasts.success({
      duration: "short",
      data: { message: i18n("reqpm.contact_list.copied") },
    });
  }

  <template>
    <ul class="reqpm-contact-list">
      {{#each this.rows as |row|}}
        <li class="reqpm-contact-list__item">
          <ReqpmKindIcon
            @kind={{row.method.kind}}
            @emoji={{row.method.emoji}}
          />
          <div class="reqpm-contact-list__body">
            <span class="reqpm-contact-list__name">{{row.name}}</span>
            <span class="reqpm-contact-list__value">{{row.method.value}}</span>
            {{#if row.method.note}}
              <span class="reqpm-contact-list__note">{{row.method.note}}</span>
            {{/if}}
          </div>
          <div class="reqpm-contact-list__actions">
            {{#if row.go}}
              {{#if row.external}}
                <a
                  href={{row.go.href}}
                  class="btn btn-default btn-small reqpm-contact-list__go"
                  target="_blank"
                  rel="noopener noreferrer nofollow"
                >
                  {{icon row.goIcon}}
                  <span class="d-button-label">{{row.goLabel}}</span>
                </a>
              {{else}}
                <a
                  href={{row.go.href}}
                  class="btn btn-default btn-small reqpm-contact-list__go"
                >
                  {{icon row.goIcon}}
                  <span class="d-button-label">{{row.goLabel}}</span>
                </a>
              {{/if}}
            {{/if}}
            <DButton
              @action={{fn this.copy row.method}}
              @icon={{if (eq this.copiedId row.method.id) "check" "copy"}}
              @title="reqpm.contact_list.copy"
              class="btn-default btn-small reqpm-contact-list__copy"
            />
          </div>
        </li>
      {{/each}}
    </ul>
  </template>
}
