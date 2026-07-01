import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

// "Desktop Pop Up Notifications" On/Off dropdown on the account preferences
// page (/u/:username/preferences/account). Rendered into the
// `user-preferences-account` outlet.
//
// It saves immediately on change with a PUT to /u/:username.json (the
// `jtech_popup_notifications_enabled` custom field is registered editable
// server-side), rather than depending on the account form's "Save Changes"
// button — the account controller does not persist arbitrary custom fields,
// and an instant toggle is the expected UX here anyway. The value is also
// mirrored onto the current user so the running toast subscriber honors the
// change without a reload.
//
// Default is OFF: the current-user serializer resolves the effective value
// from `popup_notifications_default_enabled` (false) until the user opts in,
// so the pop-up never surprises the whole forum.
export default class JtechDesktopPopupNotifications extends Component {
  @service siteSettings;
  @service currentUser;

  get available() {
    return this.siteSettings.popup_notifications_enabled;
  }

  get enabled() {
    return !!this.currentUser?.jtech_popup_notifications_enabled;
  }

  get content() {
    return [
      { id: true, name: i18n("jtech_popup_notifications.preference.on") },
      { id: false, name: i18n("jtech_popup_notifications.preference.off") },
    ];
  }

  @action
  async onChange(value) {
    const previous = this.enabled;
    // Optimistic + live gate for the running toast subscriber.
    this.currentUser.set("jtech_popup_notifications_enabled", value);
    try {
      await ajax(`/u/${this.currentUser.username}.json`, {
        type: "PUT",
        data: { custom_fields: { jtech_popup_notifications_enabled: value } },
      });
    } catch (error) {
      this.currentUser.set("jtech_popup_notifications_enabled", previous);
      popupAjaxError(error);
    }
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
