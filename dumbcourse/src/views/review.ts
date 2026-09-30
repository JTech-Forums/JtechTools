// The review queue for moderators: flagged and queued posts and new users,
// with the exact actions the server offers for each.

import { errorMessage, get, put } from "../api.ts";
import { go } from "../app.ts";
import { appPathFor } from "../content/cooked.ts";
import { timeAgo, truncate } from "../format.ts";
import { html, type SafeHtml } from "../html.ts";
import { focusContent } from "../nav.ts";
import { href, type RouteContext } from "../router.ts";
import { refreshUser } from "../session.ts";
import { avatar, categoryBadge } from "../site.ts";
import { icon } from "../ui/icons.ts";
import {
  actionSheet,
  confirmDialog,
  toast,
  type SheetItem,
} from "../ui/layers.ts";
import { decodeEntities } from "../ui/topic-row.ts";
import { useScreen } from "./common.ts";

interface ReviewAction {
  id: string;
  label: string;
  description?: string;
  confirm_message?: string;
  button_class?: string;
}

interface Reviewable {
  id: number;
  type: string;
  status: number;
  version: number;
  created_at: string;
  topic_id?: number;
  topic_url?: string;
  target_url?: string;
  category_id?: number;
  target_created_by_id?: number;
  created_by_id?: number;
  raw?: string;
  cooked?: string;
  topic_title?: string;
  topic_fancy_title?: string;
  payload?: {
    raw?: string;
    title?: string;
    username?: string;
    email?: string;
    name?: string;
  };
  reviewable_scores?: Array<{
    reason?: string;
    score_type?: { title?: string };
  }>;
  bundled_actions?: Array<{ id: string; actions: ReviewAction[] }>;
}

const TYPE_LABELS: Record<string, string> = {
  ReviewableFlaggedPost: "Flagged post",
  ReviewableQueuedPost: "Waiting for approval",
  ReviewableUser: "New user",
  ReviewablePost: "Post to review",
  ReviewableChatMessage: "Chat message",
};

function reasonOf(r: Reviewable): string {
  const scores = r.reviewable_scores || [];
  const titles: string[] = [];
  for (let i = 0; i < scores.length; i++) {
    const t =
      (scores[i].score_type && scores[i].score_type!.title) ||
      scores[i].reason ||
      "";
    if (t && titles.indexOf(t) < 0) titles.push(t);
  }
  return titles.join(", ");
}

export function reviewRoute(ctx: RouteContext): Promise<void> {
  const s = useScreen();
  s.title("Review", { back: true });
  s.loading();
  return get<{
    reviewables?: Reviewable[];
    users?: Array<{ id: number; username: string; avatar_template: string }>;
  }>("/review.json?status=pending").then(
    (d) => {
      if (!s.alive()) return;
      const items = d.reviewables || [];
      const users: Record<
        number,
        { username: string; avatar_template: string }
      > = {};
      (d.users || []).forEach((u) => (users[u.id] = u));
      if (!items.length) {
        s.empty("Nothing to review. All clear.", "check");
        return;
      }
      const rows: SafeHtml[] = items.map((r) => {
        const author = users[r.target_created_by_id || r.created_by_id || 0];
        const title = decodeEntities(
          r.topic_fancy_title ||
            r.topic_title ||
            (r.payload && r.payload.title) ||
            ""
        );
        const body =
          r.raw ||
          (r.payload && r.payload.raw) ||
          (r.payload && r.payload.username
            ? `@${r.payload.username} ${r.payload.email || ""}`
            : "");
        const reason = reasonOf(r);
        return html`<li>
          <button
            type="button"
            class="row review"
            data-act="review"
            data-id="${r.id}"
            data-key="rv${r.id}"
          >
            ${author ? avatar(author.avatar_template, 28) : icon("review")}
            <div class="row-main">
              <div class="row-title">
                ${TYPE_LABELS[r.type] ||
                r.type.replace(/^Reviewable/, "")}${reason
                  ? html` · <span class="danger-text">${reason}</span>`
                  : ""}
              </div>
              ${title
                ? html`<div class="row-meta">
                    ${categoryBadge(r.category_id)}<span>${title}</span>
                  </div>`
                : ""}
              ${body
                ? html`<div class="row-excerpt">${truncate(body, 160)}</div>`
                : ""}
              <div class="row-meta">
                ${author ? html`<span>@${author.username}</span>` : ""}<span
                  >${timeAgo(r.created_at)}</span
                >
              </div>
            </div>
          </button>
        </li>`;
      });
      s.render(
        html`<ul class="rows">
          ${rows}
        </ul>`
      );

      s.act("review", (el) => {
        const r = items.filter(
          (x) => String(x.id) === el.getAttribute("data-id")
        )[0];
        if (!r) return;
        const list: SheetItem[] = [];
        (r.bundled_actions || []).forEach((bundle) =>
          bundle.actions.forEach((a) =>
            list.push({
              label: a.label,
              danger: /danger|delete|reject/i.test(a.button_class || a.id),
              run: () => perform(r, a),
            })
          )
        );
        const where = appPathFor(r.target_url || r.topic_url || "");
        if (where)
          list.push({
            label: "Open in topic",
            icon: "jump",
            href: href(where),
          });
        actionSheet(TYPE_LABELS[r.type] || "Review", list, {
          subtitle: reasonOf(r),
        });
      });

      const perform = (r: Reviewable, a: ReviewAction) => {
        const doIt = () =>
          put(
            `/review/${r.id}/perform/${encodeURIComponent(a.id)}.json?version=${r.version}`
          ).then(
            () => {
              toast("Done.", "success");
              void refreshUser();
              go(ctx.path, { replace: true });
            },
            (e: unknown) => toast(errorMessage(e), "error")
          );
        if (a.confirm_message) {
          confirmDialog(a.confirm_message, { ok: a.label, danger: true }).then(
            (ok) => ok && void doIt()
          );
        } else {
          void doIt();
        }
      };
      if (!ctx.restore) focusContent(".row");
    },
    (e: unknown) =>
      s.error(errorMessage(e), () => go(ctx.path, { replace: true }))
  );
}
