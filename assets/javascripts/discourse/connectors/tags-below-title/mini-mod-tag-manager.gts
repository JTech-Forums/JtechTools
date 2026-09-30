import Component from "@glimmer/component";
import { service } from "@ember/service";
import htmlClass from "discourse/helpers/html-class";

interface TagManagerUser {
  staff?: boolean;
  can_admin_tags?: boolean;
}

// Mini-mods with mini_mod_manage_tags get the bulk "create tags" form on
// /tags, but the wrench menu beside it only holds staff-only tools (tag
// groups, CSV upload, delete unused). This marks the page so mini-mod.scss
// hides that menu for them.
export default class MiniModTagManager extends Component {
  @service declare currentUser: TagManagerUser | null;

  get miniModTagManager(): boolean {
    const user = this.currentUser;
    return !!user && !user.staff && !!user.can_admin_tags;
  }

  <template>
    {{#if this.miniModTagManager}}
      {{htmlClass "mini-mod-tag-manager"}}
    {{/if}}
  </template>
}
