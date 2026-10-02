import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type { ComponentLike } from "@glint/template";
import ComboBoxBase from "select-kit/components/combo-box";
import { settings, themePrefix } from "virtual:theme";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import type User from "discourse/models/user";
import { i18n } from "discourse-i18n";

interface StyleOption {
  id: string;
  name: string;
}

// Select-kit declares ComboBox without a signature.
const ComboBox = ComboBoxBase as unknown as ComponentLike<{
  Args: {
    content: StyleOption[];
    value: string;
    onChange: (value: string) => void;
  };
}>;

type IconStyleUser = User & {
  id: number;
  username: string;
  jtech_icon_style?: string;
};

interface JtIconStyleSignature {
  Args: { outletArgs?: Record<string, unknown> };
}

// "Icon style" on Preferences → Interface: the theme's Lucide outline icons
// or core's filled Font Awesome. Saves on change and reloads, since the icon
// swap happens once at boot (api-initializers/jt-lucide-icons).
export default class JtIconStyle extends Component<JtIconStyleSignature> {
  @service declare currentUser: IconStyleUser;

  // Your own preferences page only, and only while the site uses Lucide.
  get available(): boolean {
    const model = this.args.outletArgs?.model as { id?: number } | undefined;
    return (
      !!settings.lucide_icons &&
      !!this.currentUser &&
      (!model || model.id === this.currentUser.id)
    );
  }

  get value(): string {
    return this.currentUser?.jtech_icon_style === "classic"
      ? "classic"
      : "lucide";
  }

  get content(): StyleOption[] {
    return [
      { id: "lucide", name: i18n(themePrefix("jt.icon_style.lucide")) },
      { id: "classic", name: i18n(themePrefix("jt.icon_style.classic")) },
    ];
  }

  @action
  async onChange(value: string) {
    if (value === this.value) {
      return;
    }
    try {
      await ajax(`/u/${this.currentUser.username}.json`, {
        type: "PUT",
        data: { custom_fields: { jtech_icon_style: value } },
      });
      window.location.reload();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    {{#if this.available}}
      <div class="control-group jt-icon-style">
        <label class="control-label">
          {{i18n (themePrefix "jt.icon_style.title")}}
        </label>
        <div class="controls">
          <ComboBox
            @content={{this.content}}
            @onChange={{this.onChange}}
            @value={{this.value}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
