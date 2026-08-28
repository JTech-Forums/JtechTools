import { array } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @categories={{array "jtech_smart_search"}}
    @path="/admin/plugins/jtech-tools/smart-search"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
</template>
