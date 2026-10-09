import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { longDate, shortDateNoYear } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";
import ModElectionsService, {
  ModElection,
  ModElectionCandidate,
  ModElectionPage,
} from "../services/mod-elections";
import ModElectionsBallot from "./mod-elections-ballot";
import ModElectionsCandidate from "./mod-elections-candidate";
import ModElectionsResults from "./mod-elections-results";
import ModElectionsRun from "./mod-elections-run";

type StepState = "done" | "current" | "upcoming";

interface Step {
  id: string;
  label: string;
  date: string;
  state: StepState;
}

interface ModElectionsPageSignature {
  Args: {
    // The ?id= query param: a past election, or blank for the current one.
    electionId?: string | null;
  };
}

const ORDER = ["nominating", "voting", "closed", "published"];

// Month and year an election ran, for the list of past ones.
const monthOf = (date: string): string =>
  new Date(date).toLocaleDateString(
    document.documentElement.lang || undefined,
    {
      month: "long",
      year: "numeric",
    }
  );

// /elections — what step the election is at, who's running, your part in
// it (running, or your ballot), and the results once they're published.
export default class ModElectionsPage extends Component<ModElectionsPageSignature> {
  @service declare modElections: ModElectionsService;

  @tracked page: ModElectionPage | null = null;
  @tracked loading = true;

  constructor(owner: Owner, args: ModElectionsPageSignature["Args"]) {
    super(owner, args);
    this.load();
  }

  get election(): ModElection | null {
    return this.page?.election || null;
  }

  get status(): string | null {
    return this.election?.status || null;
  }

  get candidates(): ModElectionCandidate[] {
    return this.election?.candidates || [];
  }

  get runningCount(): number {
    return this.candidates.filter((c) => c.status === "running").length;
  }

  // When the current step ends, beside its name at the top.
  get statusDetail(): string | null {
    const election = this.election;
    if (!election) {
      return null;
    }
    const ends =
      election.status === "nominating"
        ? election.voting_open_at
        : election.status === "voting"
          ? election.voting_close_at
          : null;
    return ends ? i18n("mod_elections.until", { date: longDate(ends) }) : null;
  }

  get steps(): Step[] {
    const election = this.election;
    if (!election || election.status === "cancelled") {
      return [];
    }
    const at = ORDER.indexOf(election.status);
    const state = (index: number): StepState =>
      at > index ? "done" : at === index ? "current" : "upcoming";
    return [
      {
        id: "nominations",
        label: i18n("mod_elections.steps.nominations"),
        date: shortDateNoYear(election.nominations_open_at),
        state: state(0),
      },
      {
        id: "voting",
        label: i18n("mod_elections.steps.voting"),
        date: shortDateNoYear(election.voting_open_at),
        state: state(1),
      },
      {
        id: "results",
        label: i18n("mod_elections.steps.results"),
        date: shortDateNoYear(election.voting_close_at),
        // "Counting" and "Results" are the same step on the strip.
        state: at >= 3 ? "done" : at === 2 ? "current" : "upcoming",
      },
    ];
  }

  get canVote(): boolean {
    const me = this.page?.me;
    return !!me && this.status === "voting" && !me.vote_blocked;
  }

  get voteBlockedMessage(): string | null {
    const reason = this.page?.me?.vote_blocked;
    if (!reason) {
      return null;
    }
    return i18n(`mod_elections.blocked.${reason}`, {
      days: this.page?.limits.voter_min_account_age_days,
    });
  }

  get history() {
    const current = this.election?.id;
    return (this.page?.history || [])
      .filter((row) => row.id !== current)
      .map((row) => ({ ...row, label: monthOf(row.nominations_open_at) }));
  }

  @action
  async load() {
    this.loading = true;
    try {
      this.page = await this.modElections.page(this.args.electionId);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  updated(page: ModElectionPage) {
    this.page = page;
  }

  <template>
    <div class="mod-elections" {{didUpdate this.load @electionId}}>
      <header class="mod-elections__header">
        <h1>{{i18n "mod_elections.title"}}</h1>
        {{#if this.election}}
          <span
            class="mod-elections-status mod-elections-status--{{this.status}}"
          >
            {{i18n (concat "mod_elections.status." this.status)}}
            {{#if this.statusDetail}}
              <span class="mod-elections-muted">{{this.statusDetail}}</span>
            {{/if}}
          </span>
        {{/if}}
      </header>

      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.election}}
          {{#if this.steps.length}}
            <ol class="mod-elections-steps">
              {{#each this.steps as |step|}}
                <li
                  class="mod-elections-steps__step mod-elections-steps__step--{{step.state}}"
                  data-step={{step.id}}
                >
                  <span class="mod-elections-steps__label">{{step.label}}</span>
                  <span class="mod-elections-steps__date">{{step.date}}</span>
                </li>
              {{/each}}
            </ol>
          {{/if}}

          <div class="mod-elections__meta">
            <span>{{icon "users"}}
              {{i18n "mod_elections.seats" count=this.election.seats}}</span>
            {{#if this.election.topic_url}}
              <a href={{this.election.topic_url}}>{{icon "far-comments"}}
                {{i18n "mod_elections.discussion"}}</a>
            {{/if}}
          </div>

          {{#if (eq this.status "cancelled")}}
            <p class="mod-elections-panel">{{i18n
                "mod_elections.cancelled"
              }}</p>
          {{else if (eq this.status "published")}}
            {{#if this.election.result}}
              <ModElectionsResults
                @candidates={{this.election.candidates}}
                @result={{this.election.result}}
                @turnout={{this.election.turnout}}
              />
            {{/if}}
          {{else}}
            {{#if (eq this.status "nominating")}}
              {{#if this.page.me}}
                <ModElectionsRun
                  @election={{this.election}}
                  @limits={{this.page.limits}}
                  @me={{this.page.me}}
                  @onChange={{this.updated}}
                />
              {{/if}}
            {{else if (eq this.status "voting")}}
              {{#if this.canVote}}
                <ModElectionsBallot
                  @election={{this.election}}
                  @me={{this.page.me}}
                  @onChange={{this.updated}}
                />
              {{else if this.voteBlockedMessage}}
                <p class="mod-elections-panel mod-elections-muted">
                  {{this.voteBlockedMessage}}
                </p>
              {{/if}}
            {{else if (eq this.status "closed")}}
              <section class="mod-elections-panel">
                <h2>{{i18n "mod_elections.closed.title"}}</h2>
                <p class="mod-elections-muted">{{i18n
                    "mod_elections.closed.body"
                  }}</p>
              </section>
            {{/if}}

            {{#unless this.canVote}}
              <section class="mod-elections-candidates">
                <h2>
                  {{i18n "mod_elections.candidates.title"}}
                  <span class="mod-elections-count">{{this.runningCount}}</span>
                </h2>
                {{#each this.candidates as |candidate|}}
                  <ModElectionsCandidate @candidate={{candidate}} />
                {{else}}
                  <p class="mod-elections-muted">{{i18n
                      "mod_elections.candidates.none"
                    }}</p>
                {{/each}}
              </section>
            {{/unless}}
          {{/if}}
        {{else}}
          <div class="mod-elections-empty">
            {{icon "check-to-slot"}}
            <p>{{i18n "mod_elections.empty"}}</p>
          </div>
        {{/if}}

        {{#if this.history.length}}
          <section class="mod-elections-history">
            <h2>{{i18n "mod_elections.history.title"}}</h2>
            <ul>
              {{#each this.history as |row|}}
                <li>
                  <LinkTo @query={{hash id=row.id}} @route="mod-elections">
                    {{row.label}}
                  </LinkTo>
                  {{#if (eq row.status "cancelled")}}
                    <span class="mod-elections-muted">{{i18n
                        "mod_elections.history.cancelled"
                      }}</span>
                  {{/if}}
                </li>
              {{/each}}
            </ul>
          </section>
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
