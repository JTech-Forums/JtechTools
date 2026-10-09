import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import type {
  ModElectionCandidate,
  ModElectionResult,
  ModElectionResultCandidate,
  ModElectionStage,
  ModElectionTurnout,
} from "../services/mod-elections";

interface ModElectionsResultsSignature {
  Args: {
    result: ModElectionResult;
    turnout?: ModElectionTurnout | null;
    // The election's candidates now, for seats left since the count.
    candidates?: ModElectionCandidate[];
  };
}

interface ResultCell {
  value: string;
  elected: boolean;
  out: boolean;
}

interface ResultRow {
  candidate: ModElectionResultCandidate;
  elected: boolean;
  cells: ResultCell[];
}

interface StageColumn {
  number: number;
  label: string;
}

const profileUrl = (username: string | null): string =>
  getURL(`/u/${username || ""}`);

// Rounded for reading; the server counts exactly.
const formatVotes = (value: number): string =>
  value.toLocaleString(undefined, { maximumFractionDigits: 2 });

// Winners, turnout, and the count stage by stage, so anyone can follow how
// each seat was won.
export default class ModElectionsResults extends Component<ModElectionsResultsSignature> {
  get people(): Map<number, ModElectionResultCandidate> {
    return new Map(this.args.result.candidates.map((c) => [c.id, c]));
  }

  get winners(): (ModElectionResultCandidate & { note: string | null })[] {
    const now = new Map((this.args.candidates || []).map((c) => [c.id, c]));
    return this.args.result.elected
      .map((id) => this.people.get(id))
      .filter((c): c is ModElectionResultCandidate => !!c)
      .map((c) => {
        const left = now.get(c.id)?.seat_left_reason;
        return {
          ...c,
          note: left ? i18n(`mod_elections.results.left.${left}`) : null,
        };
      });
  }

  get countbacks(): string[] {
    return (this.args.result.countbacks || []).map((row) =>
      i18n("mod_elections.results.countback", {
        username: this.name(row.candidate),
      })
    );
  }

  get ballotsLine(): string {
    const ballots = i18n("mod_elections.results.ballots", {
      count: this.args.result.ballots,
    });
    const voters = this.args.turnout?.voters;
    if (!voters) {
      return ballots;
    }
    const percent = Math.round((this.args.result.ballots / voters) * 100);
    return `${ballots} · ${i18n("mod_elections.results.of_voters", {
      percent,
      voters,
    })}`;
  }

  get quotaLine(): string {
    return i18n("mod_elections.results.quota", {
      quota: formatVotes(this.args.result.quota),
    });
  }

  get columns(): StageColumn[] {
    return this.args.result.stages.map((stage) => ({
      number: stage.number,
      label: this.stageLabel(stage),
    }));
  }

  // Winners first in the order they were elected, then everyone else by
  // how far they got.
  get rows(): ResultRow[] {
    const stages = this.args.result.stages;
    const elected = this.args.result.elected;
    const outAt = new Map<number, number>();
    const electedAt = new Map<number, number>();
    stages.forEach((stage) => {
      if (stage.action === "exclusion" && stage.candidate !== null) {
        outAt.set(stage.candidate, stage.number);
      }
      stage.elected.forEach((id) => electedAt.set(id, stage.number));
    });

    const reach = (id: number): number[] => {
      const last = outAt.get(id) ?? stages.length + 1;
      return [
        -last,
        -(stages[Math.max(last - 2, 0)]?.tallies[String(id)] || 0),
      ];
    };

    const others = this.args.result.candidates
      .filter((c) => !elected.includes(c.id))
      .sort((a, b) => {
        const [ra, va] = reach(a.id);
        const [rb, vb] = reach(b.id);
        return ra - rb || va - vb;
      });
    const order = [
      ...elected
        .map((id) => this.people.get(id))
        .filter((c): c is ModElectionResultCandidate => !!c),
      ...others,
    ];

    return order.map((candidate) => ({
      candidate,
      elected: elected.includes(candidate.id),
      cells: stages.map((stage) => {
        const out = (outAt.get(candidate.id) ?? Infinity) <= stage.number;
        return {
          value: out
            ? "—"
            : formatVotes(stage.tallies[String(candidate.id)] || 0),
          elected: electedAt.get(candidate.id) === stage.number,
          out,
        };
      }),
    }));
  }

  get exhaustedCells(): string[] {
    return this.args.result.stages.map((stage) => formatVotes(stage.exhausted));
  }

  get ties(): string[] {
    return this.args.result.stages
      .filter((stage) => stage.tie)
      .map((stage) => {
        const tie = stage.tie!;
        const names = tie.among.map((id) => this.name(id)).join(", ");
        return tie.method === "lot"
          ? i18n("mod_elections.results.tie_lot", {
              names,
              seed: this.args.result.seed,
            })
          : i18n("mod_elections.results.tie_earlier_stage", { names });
      });
  }

  name(id: number | null): string {
    return (id !== null && this.people.get(id)?.username) || "?";
  }

  stageLabel(stage: ModElectionStage): string {
    switch (stage.action) {
      case "surplus":
        return i18n("mod_elections.results.stage_surplus", {
          username: this.name(stage.candidate),
        });
      case "exclusion":
        return i18n("mod_elections.results.stage_exclusion", {
          username: this.name(stage.candidate),
        });
      case "unopposed":
        return i18n("mod_elections.results.stage_unopposed");
      default:
        return i18n("mod_elections.results.stage_first");
    }
  }

  <template>
    <section class="mod-elections-panel mod-elections-results">
      <h2>{{i18n "mod_elections.results.title"}}</h2>

      {{#if this.winners.length}}
        <ol class="mod-elections-results__winners">
          {{#each this.winners as |winner|}}
            <li class="mod-elections-results__winner">
              <a
                data-user-card={{winner.username}}
                href={{profileUrl winner.username}}
              >{{avatar winner imageSize="large"}}</a>
              <div>
                <a
                  class="mod-elections-results__winner-name"
                  data-user-card={{winner.username}}
                  href={{profileUrl winner.username}}
                >{{winner.username}}</a>
                {{#if winner.note}}
                  <span class="mod-elections-muted">{{winner.note}}</span>
                {{else}}
                  <span class="mod-elections-chip mod-elections-chip--strong">
                    {{icon "trophy"}}
                    {{i18n "mod_elections.candidates.elected"}}
                  </span>
                {{/if}}
              </div>
            </li>
          {{/each}}
        </ol>
      {{else}}
        <p class="mod-elections-muted">{{i18n "mod_elections.results.none"}}</p>
      {{/if}}

      {{#each this.countbacks as |line|}}
        <p class="mod-elections-muted">{{line}}</p>
      {{/each}}

      <p class="mod-elections-results__stats">
        <span>{{this.ballotsLine}}</span>
        <span>{{this.quotaLine}}</span>
      </p>

      <h3>{{i18n "mod_elections.results.count_title"}}</h3>
      <div class="mod-elections-results__scroll">
        <table class="mod-elections-results__table">
          <thead>
            <tr>
              <th scope="col">{{i18n "mod_elections.results.candidate"}}</th>
              {{#each this.columns as |column|}}
                <th scope="col">
                  <span
                    class="mod-elections-results__stage-number"
                  >{{column.number}}</span>
                  <span
                    class="mod-elections-results__stage-label"
                  >{{column.label}}</span>
                </th>
              {{/each}}
            </tr>
          </thead>
          <tbody>
            {{#each this.rows as |row|}}
              <tr
                class={{if row.elected "mod-elections-results__row--elected"}}
              >
                <th scope="row">
                  {{avatar row.candidate imageSize="tiny"}}
                  {{row.candidate.username}}
                </th>
                {{#each row.cells as |cell|}}
                  <td
                    class="{{if cell.elected 'is-elected'}}
                      {{if cell.out 'is-out'}}"
                  >
                    {{cell.value}}
                    {{#if cell.elected}}{{icon "check"}}{{/if}}
                  </td>
                {{/each}}
              </tr>
            {{/each}}
            <tr class="mod-elections-results__exhausted">
              <th scope="row">{{i18n "mod_elections.results.exhausted"}}</th>
              {{#each this.exhaustedCells as |value|}}
                <td>{{value}}</td>
              {{/each}}
            </tr>
          </tbody>
        </table>
      </div>

      {{#each this.ties as |line|}}
        <p class="mod-elections-muted">{{line}}</p>
      {{/each}}

      <details class="mod-elections-results__how">
        <summary>{{i18n "mod_elections.results.how"}}</summary>
        <p>{{i18n "mod_elections.results.how_body"}}</p>
      </details>
    </section>
  </template>
}
