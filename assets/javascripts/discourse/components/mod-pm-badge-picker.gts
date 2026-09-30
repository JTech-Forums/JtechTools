import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import ComboBox from "select-kit/components/combo-box";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import type Composer from "discourse/models/composer";
import type StoreService from "discourse/services/store";
import { i18n } from "discourse-i18n";

// The badge fields read off `store.findAll("badge")` records.
export interface BadgeRecord {
  id: number;
  name: string;
  display_name?: string;
  enabled?: boolean;
}

export interface BadgeChoice {
  id: number;
  name: string;
}

interface BadgeMembersResponse {
  usernames?: string[];
}

export type RecipientsComposer = Composer & { targetRecipients?: string };

interface ModPmBadgePickerSignature {
  Args: {
    model: { composer: RecipientsComposer };
    closeModal: () => void;
  };
}

// Picks a single badge, fetches the current holders' usernames, and
// splices them into the PM composer's targetRecipients string (deduped,
// comma-joined per Discourse convention). The PM is then sent through the
// normal PostCreator path with that union as recipients — badge-grant
// changes after send do NOT propagate, by design (a PM is a fixed-recipient
// conversation).
export default class ModPmBadgePicker extends Component<ModPmBadgePickerSignature> {
  @service declare store: StoreService;

  @tracked badgeChoices: BadgeChoice[] = [];
  @tracked selectedBadgeId: number | null = null;
  @tracked saving = false;

  constructor(owner: Owner, args: ModPmBadgePickerSignature["Args"]) {
    super(owner, args);
    this.#loadBadges();
  }

  @action
  updateBadge(id: string | number | null) {
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
      const data: BadgeMembersResponse | null = await ajax(
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

  async #loadBadges() {
    try {
      const list = await this.store.findAll("badge", undefined);
      this.badgeChoices = (list?.content || list || [])
        .filter((b: BadgeRecord | null) => b?.enabled !== false)
        .map((b: BadgeRecord) => ({
          id: b.id,
          name: b.display_name || b.name,
        }));
    } catch {
      this.badgeChoices = [];
    }
  }

  <template>
    <DModal
      class="mod-pm-badge-picker-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_mod_categories.pm_badge.modal_title"}}
    >
      <:body>
        <ComboBox
          @content={{this.badgeChoices}}
          @nameProperty="name"
          @onChange={{this.updateBadge}}
          @options={{hash
            filterPlaceholder="discourse_mod_categories.pm_badge.search_placeholder"
            none="discourse_mod_categories.pm_badge.none"
          }}
          @value={{this.selectedBadgeId}}
          @valueProperty="id"
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.confirm}}
          @disabled={{this.saving}}
          @label="discourse_mod_categories.pm_badge.confirm"
        />
      </:footer>
    </DModal>
  </template>
}
