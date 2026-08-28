import AdminAreaSettingsBaseController from "discourse/admin/controllers/admin-area-settings-base";

// Supplies the filter query param and adminSettingsFilterChangedCallback the
// AdminAreaSettings component requires — it calls the callback from its
// constructor, so a bare Controller here would TypeError on first render.
export default class JtechToolsDisteleplusController extends AdminAreaSettingsBaseController {}
