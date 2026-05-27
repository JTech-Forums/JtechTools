import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

// Picks a single badge, fetches the current holders' usernames, and
// splices them into the PM composer's targetRecipients string (deduped,
// comma-joined per Discourse convention). The PM is then sent through the
// normal PostCreator path with that union as recipients — badge-grant
// changes after send do NOT propagate, by design (a PM is a fixed-recipient
// conversation).
export default class ModPmBadgePicker extends Component {
  @service store;

  @tracked badgeChoices = [];
  @tracked selectedBadgeId = null;
  @tracked saving = false;

  constructor() {
    super(...arguments);
    this.#loadBadges();
  }

  async #loadBadges() {
    try {
      const list = await this.store.findAll("badge");
      this.badgeChoices = (list?.content || list || [])
        .filter((b) => b?.enabled !== false)
        .map((b) => ({ id: b.id, name: b.display_name || b.name }));
    } catch (_e) {
      this.badgeChoices = [];
    }
  }

  @action
  updateBadge(id) {
    this.selectedBadgeId = id ? Number(id) : null;
  }

  @action
  async confirm() {
    const composer = this.args.model?.composer;
    if (!composer || !this.selectedBadgeId) {
      this.args.closeModal();
      return;
    }

    this.saving = true;
    try {
      const data = await ajax(
        `/discourse-mod-categories/badge-members/${this.selectedBadgeId}.json`
      );
      const newUsernames = Array.isArray(data?.usernames) ? data.usernames : [];

      const current = (composer.targetRecipients || "")
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      const merged = [...new Set([...current, ...newUsernames])];
      composer.set("targetRecipients", merged.join(","));

      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_mod_categories.pm_badge.modal_title"}}
      @closeModal={{@closeModal}}
      class="mod-pm-badge-picker-modal"
    >
      <:body>
        <p>{{i18n "discourse_mod_categories.pm_badge.modal_instructions"}}</p>
        <ComboBox
          @value={{this.selectedBadgeId}}
          @content={{this.badgeChoices}}
          @nameProperty="name"
          @valueProperty="id"
          @onChange={{this.updateBadge}}
          @options={{hash
            filterPlaceholder="discourse_mod_categories.pm_badge.search_placeholder"
            none="discourse_mod_categories.pm_badge.none"
          }}
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.confirm}}
          @label="discourse_mod_categories.pm_badge.confirm"
          @disabled={{this.saving}}
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
