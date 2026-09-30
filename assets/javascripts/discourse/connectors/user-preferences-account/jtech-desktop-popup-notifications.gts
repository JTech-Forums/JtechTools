import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type { ComponentLike } from "@glint/template";
import ComboBoxBase from "select-kit/components/combo-box";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import type User from "discourse/models/user";
import type SiteSettingsService from "discourse/services/site-settings";
import { i18n } from "discourse-i18n";

interface ToggleOption {
  id: boolean;
  name: string;
}

// Select-kit declares ComboBox without a signature.
const ComboBox = ComboBoxBase as unknown as ComponentLike<{
  Args: {
    content: ToggleOption[];
    value: boolean;
    onChange: (value: boolean) => void;
  };
}>;

type PopupSiteSettings = SiteSettingsService & {
  popup_notifications_enabled: boolean;
};

type PopupCurrentUser = User & {
  username: string;
  jtech_popup_notifications_enabled?: boolean;
};

interface JtechDesktopPopupNotificationsSignature {
  Args: { outletArgs?: Record<string, unknown> };
}

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
export default class JtechDesktopPopupNotifications extends Component<JtechDesktopPopupNotificationsSignature> {
  @service declare siteSettings: PopupSiteSettings;
  @service declare currentUser: PopupCurrentUser;

  get available(): boolean {
    return this.siteSettings.popup_notifications_enabled;
  }

  get enabled(): boolean {
    return !!this.currentUser?.jtech_popup_notifications_enabled;
  }

  get content(): ToggleOption[] {
    return [
      { id: true, name: i18n("jtech_popup_notifications.preference.on") },
      { id: false, name: i18n("jtech_popup_notifications.preference.off") },
    ];
  }

  @action
  async onChange(value: boolean) {
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
            @onChange={{this.onChange}}
            @value={{this.enabled}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
