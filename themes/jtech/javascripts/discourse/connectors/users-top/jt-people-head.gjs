import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import { i18n } from "discourse-i18n";

const PERIODS = ["daily", "weekly", "monthly", "quarterly", "yearly", "all"];
const count = new Intl.NumberFormat();

// Users directory header: "People" + member count, and the period as a
// segmented switch (core's period dropdown is hidden in jt-directory.scss;
// this drives the same `period` query param).
export default class JtPeopleHead extends Component {
  @service router;

  get current() {
    return this.router.currentRoute?.queryParams?.period || "weekly";
  }

  get periods() {
    return PERIODS.map((id) => ({
      id,
      label: i18n(themePrefix(`jt.people.period_${id}`)),
      active: id === this.current,
    }));
  }

  get total() {
    const n = this.args.outletArgs?.model?.totalRows;
    return n ? count.format(n) : null;
  }

  @action
  choose(period) {
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
        class="jt-seg"
        role="radiogroup"
        aria-label={{i18n (themePrefix "jt.people.period")}}
      >
        {{#each this.periods as |p|}}
          <button
            type="button"
            role="radio"
            aria-checked={{if p.active "true" "false"}}
            class="jt-seg__item {{if p.active '--active'}}"
            {{on "click" (fn this.choose p.id)}}
          >{{p.label}}</button>
        {{/each}}
      </div>
    </header>
  </template>
}
