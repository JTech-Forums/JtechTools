import { array } from "@ember/helper";
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import JtechAdminActions from "../../../components/jtech-admin-actions";

// Maintenance actions rendered as real buttons (the legacy flip-a-checkbox
// *_now settings are hidden; their hooks remain for API callers).
const ACTIONS = [
  { id: "register_webhook", icon: "rotate", confirm: true },
  { id: "send_test_message", icon: "paper-plane" },
  { id: "sync_notifications", icon: "bell" },
  { id: "measure_forum_uploads", icon: "chart-bar", confirm: true },
  { id: "backfill_forum_uploads", icon: "upload", confirm: true },
];

export default <template>
  <AdminAreaSettings
    @categories={{array "jtech_disteleplus"}}
    @path="/admin/plugins/jtech-tools/disteleplus"
    @filter={{@controller.filter}}
    @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    @showBreadcrumb={{false}}
  />
  <JtechAdminActions @actions={{ACTIONS}} />
</template>
