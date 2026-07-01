import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

// "Desktop Pop Up Notifications" On/Off dropdown on the account preferences
// page (/u/:username/preferences/account). Persists to the
// `jtech_popup_notifications_enabled` user custom field (registered editable
// server-side) via the page's normal "Save Changes" button, and mirrors the
// chosen value onto the current user so the running toast subscriber honors
// the change without a reload.
//
// Default is OFF: until a user opts in here, `enabled` resolves to the
// site's `popup_notifications_default_enabled` (false), so the pop-up never
// surprises the whole forum.
export default class JtechDesktopPopupNotifications extends Component {
  @service siteSettings;
  @service currentUser;

  get model() {
    return this.args.outletArgs?.model;
  }

  get available() {
    return this.siteSettings.popup_notifications_enabled;
  }

  get enabled() {
    const raw = this.model?.custom_fields?.jtech_popup_notifications_enabled;
    if (raw === undefined || raw === null || raw === "") {
      return this.siteSettings.popup_notifications_default_enabled;
    }
    return raw === true || raw === "true" || raw === "t";
  }

  get content() {
    return [
      { id: true, name: i18n("jtech_popup_notifications.preference.on") },
      { id: false, name: i18n("jtech_popup_notifications.preference.off") },
    ];
  }

  @action
  onChange(value) {
    this.model?.set("custom_fields.jtech_popup_notifications_enabled", value);
    this.currentUser?.set("jtech_popup_notifications_enabled", value);
  }

  <template>
    {{#if this.available}}
      <div class="control-group jtech-desktop-popup-notifications">
        <label class="control-label">
          {{i18n "jtech_popup_notifications.preference.title"}}
        </label>
        <div class="controls">
          <ComboBox
            @content={{this.content}}
            @value={{this.enabled}}
            @onChange={{this.onChange}}
          />
          <div class="instructions">
            {{i18n "jtech_popup_notifications.preference.instructions"}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
