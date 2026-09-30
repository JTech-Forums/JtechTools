import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { array } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import type AdminAreaSettingsBaseController from "discourse/admin/controllers/admin-area-settings-base";

const JtechToolsReqpm: TemplateOnlyComponent<{
  Args: { controller: AdminAreaSettingsBaseController };
}> = <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @categories={{array "jtech_reqpm"}}
    @filter={{@controller.filter}}
    @path="/admin/plugins/jtech-tools/reqpm"
    @showBreadcrumb={{false}}
  />
</template>;

export default JtechToolsReqpm;
