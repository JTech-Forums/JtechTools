import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { array } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import type AdminAreaSettingsBaseController from "discourse/admin/controllers/admin-area-settings-base";

const JtechToolsUsernameAvatar: TemplateOnlyComponent<{
  Args: { controller: AdminAreaSettingsBaseController };
}> = <template>
  <AdminAreaSettings
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @categories={{array "jtech_username_avatar"}}
    @filter={{@controller.filter}}
    @path="/admin/plugins/jtech-tools/username-avatar"
    @showBreadcrumb={{false}}
  />
</template>;

export default JtechToolsUsernameAvatar;
