import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { array } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import type AdminAreaSettingsBaseController from "discourse/admin/controllers/admin-area-settings-base";

const JtechToolsPopups: TemplateOnlyComponent<{
  Args: { controller: AdminAreaSettingsBaseController };
}> = <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @categories={{array "jtech_popup_notifications"}}
    @filter={{@controller.filter}}
    @path="/admin/plugins/jtech-tools/popups"
    @showBreadcrumb={{false}}
  />
</template>;

export default JtechToolsPopups;
