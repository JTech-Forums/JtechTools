import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import type ResultSet from "discourse/models/result-set";
import { i18n } from "discourse-i18n";

// The labels are core's own (its period chooser shows the same words), so
// they come in every language the forum offers: the theme's English copies
// left Hebrew readers a switch of English words.
const PERIOD_TITLES: Record<string, string> = {
  daily: "today",
  weekly: "this_week",
  monthly: "this_month",
  quarterly: "this_quarter",
  yearly: "this_year",
  all: "all_time",
};
const PERIODS = Object.keys(PERIOD_TITLES);
const count = new Intl.NumberFormat();

interface PeriodOption {
  id: string;
  label: string;
  active: boolean;
}

interface JtPeopleHeadSignature {
  Args: { outletArgs: { model?: ResultSet } };
}

// Users directory header: "People" + member count, and the period as a
// segmented switch (core's period dropdown is hidden in jt-directory.scss;
// this drives the same `period` query param).
export default class JtPeopleHead extends Component<JtPeopleHeadSignature> {
  @service declare router: RouterService;

  get current(): string {
    // RouteInfo types query param values as unknown; `period` is a string.
    return (
      (this.router.currentRoute?.queryParams?.period as string | undefined) ||
      "weekly"
    );
  }

  get periods(): PeriodOption[] {
    return PERIODS.map((id) => ({
      id,
      label: i18n(`filters.top.${PERIOD_TITLES[id]}`),
      active: id === this.current,
    }));
  }

  get total(): string | null {
    const n = this.args.outletArgs?.model?.totalRows;
    return n ? count.format(n) : null;
  }

  @action
  choose(period: string) {
    this.router.transitionTo({ queryParams: { period } });
  }

  <template>
    <header class="jt-people-head">
      <h1 class="jt-people-head__title">
        {{i18n (themePrefix "jt.people.title")}}
        {{#if this.total}}
          <span class="jt-people-head__count">{{this.total}}</span>
        {{/if}}
      </h1>
      <div
        aria-label={{i18n (themePrefix "jt.people.period")}}
        class="jt-seg"
        role="radiogroup"
      >
        {{#each this.periods as |p|}}
          <button
            aria-checked={{if p.active "true" "false"}}
            class="jt-seg__item {{if p.active '--active'}}"
            role="radio"
            type="button"
            {{on "click" (fn this.choose p.id)}}
          >{{p.label}}</button>
        {{/each}}
      </div>
    </header>
  </template>
}
