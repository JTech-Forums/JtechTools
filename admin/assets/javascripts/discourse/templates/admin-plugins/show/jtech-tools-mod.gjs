import { array } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";

export default <template>
  <AdminAreaSettings
    @categories={{array
      "jtech_mod"
      "jtech_mod_topic_tools"
      "jtech_mod_checklists"
      "jtech_mod_notes"
      "jtech_mod_notifications"
      "jtech_mod_whispers"
    }}
    @path="/admin/plugins/jtech-tools/mod"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
</template>
