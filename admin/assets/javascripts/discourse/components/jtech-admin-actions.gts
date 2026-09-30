import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import type DialogService from "discourse/dialog-holder/services/dialog";
import type ToastsService from "discourse/float-kit/services/toasts";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

// `id` keys the endpoint and the i18n strings under
// admin.jtech_tools.actions.<id>.{label,confirm,done}.
export interface AdminAction {
  id: string;
  icon: string;
  confirm?: boolean;
}

interface JtechAdminActionsSignature {
  Args: { actions: AdminAction[] };
}

// Maintenance actions as actual buttons.
export default class JtechAdminActions extends Component<JtechAdminActionsSignature> {
  @service declare dialog: DialogService;
  @service declare toasts: ToastsService;

  @tracked running: string | null = null;

  get busy(): boolean {
    return this.running !== null;
  }

  @action
  run(descriptor: AdminAction) {
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

  label(descriptor: AdminAction) {
    return i18n(`admin.jtech_tools.actions.${descriptor.id}.label`);
  }

  <template>
    <div class="jtech-admin-actions">
      <h3>{{i18n "admin.jtech_tools.actions.title"}}</h3>
      <div class="jtech-admin-actions__buttons">
        {{#each @actions as |descriptor|}}
          <DButton
            class="btn-default"
            @action={{fn this.run descriptor}}
            @disabled={{this.busy}}
            @icon={{descriptor.icon}}
            @isLoading={{eq this.running descriptor.id}}
            @translatedLabel={{this.label descriptor}}
          />
        {{/each}}
      </div>
    </div>
  </template>
}
