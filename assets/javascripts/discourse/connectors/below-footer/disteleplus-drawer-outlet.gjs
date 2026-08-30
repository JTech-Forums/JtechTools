import Component from "@glimmer/component";
import { service } from "@ember/service";
import DisteleplusDrawer from "../../components/disteleplus-drawer";

// Same mount point core Chat uses for its drawer.
export default class DisteleplusDrawerOutlet extends Component {
  @service currentUser;
  @service siteSettings;

  get canInteract() {
    return (
      this.siteSettings.disteleplus_enabled &&
      this.currentUser?.can_access_disteleplus
    );
  }

  <template>
    {{#if this.canInteract}}
      <div class="below-footer-outlet disteleplus-drawer-outlet">
        <DisteleplusDrawer />
      </div>
    {{/if}}
  </template>
}
