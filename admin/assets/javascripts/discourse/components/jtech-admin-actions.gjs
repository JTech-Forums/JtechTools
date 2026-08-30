import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

// Maintenance actions as actual buttons. Each descriptor:
//   { id, icon, confirm? } — id keys the endpoint and the i18n strings under
//   admin.jtech_tools.actions.<id>.{label,confirm,done}.
export default class JtechAdminActions extends Component {
  @service dialog;
  @service toasts;

  @tracked running = null;

  @action
  run(descriptor) {
    const perform = async () => {
      this.running = descriptor.id;
      try {
        await ajax(`/admin/plugins/jtech-tools/actions/${descriptor.id}`, {
          type: "POST",
        });
        this.toasts.success({
          duration: 5000,
          data: {
            message: i18n(`admin.jtech_tools.actions.${descriptor.id}.done`),
          },
        });
      } catch (error) {
        popupAjaxError(error);
      } finally {
        this.running = null;
      }
    };

    if (descriptor.confirm) {
      this.dialog.confirm({
        message: i18n(`admin.jtech_tools.actions.${descriptor.id}.confirm`),
        didConfirm: perform,
      });
    } else {
      perform();
    }
  }

  label(descriptor) {
    return i18n(`admin.jtech_tools.actions.${descriptor.id}.label`);
  }

  <template>
    <div class="jtech-admin-actions">
      <h3>{{i18n "admin.jtech_tools.actions.title"}}</h3>
      <p class="jtech-admin-actions__hint">
        {{i18n "admin.jtech_tools.actions.hint"}}
      </p>
      <div class="jtech-admin-actions__buttons">
        {{#each @actions as |descriptor|}}
          <DButton
            @icon={{descriptor.icon}}
            @translatedLabel={{this.label descriptor}}
            @action={{fn this.run descriptor}}
            @isLoading={{eq this.running descriptor.id}}
            @disabled={{this.running}}
            class="btn-default"
          />
        {{/each}}
      </div>
    </div>
  </template>
}
