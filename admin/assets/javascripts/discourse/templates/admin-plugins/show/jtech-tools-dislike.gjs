import { array } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import JtechAdminActions from "../../../components/jtech-admin-actions";

// The purge used to be a self-resetting checkbox setting; it is a button now.
const ACTIONS = [
  { id: "purge_phantom_likes", icon: "trash-can", confirm: true },
];

export default <template>
  <AdminAreaSettings
    @categories={{array "jtech_dislike"}}
    @path="/admin/plugins/jtech-tools/dislike"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
  <JtechAdminActions @actions={{ACTIONS}} />
</template>
