import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

// "REQ-PM" button on someone's user card and profile. Hidden on your own,
// and for accounts that can't take part (bots, staged, suspended…).
export default class ReqpmUserButton extends Component {
  @service reqpm;
  @service currentUser;

  get show() {
    const user = this.args.user;
    return (
      this.reqpm.available &&
      user?.username &&
      user.id !== this.currentUser?.id &&
      user.id > 0 &&
      user.reqpm_available !== false
    );
  }

  @action
  open() {
    const user = this.args.user;
    this.args.close?.();
    this.reqpm.openUser({
      id: user.id,
      username: user.username,
      name: user.name,
      avatar_template: user.avatar_template,
    });
  }

  <template>
    {{#if this.show}}
      <DButton
        @action={{this.open}}
        @icon="address-card"
        @label="reqpm.button.label"
        @title="reqpm.button.title"
        class="btn-primary reqpm-user-button"
      />
    {{/if}}
  </template>
}
