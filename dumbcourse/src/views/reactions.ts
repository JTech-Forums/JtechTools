// Reaction picker and "who reacted" list.

import { errorMessage, get } from "../api.ts";
import { settings } from "../config.ts";
import { emojiImg } from "../content/emoji.ts";
import { $$ } from "../dom.ts";
import { html } from "../html.ts";
import { href } from "../router.ts";
import { avatar, userPath } from "../site.ts";
import type { Post } from "../types.ts";
import { actionSheet, openLayer, toast, type SheetItem } from "../ui/layers.ts";
import { LIKE, reactionsOn } from "../ui/post.ts";

export function reactionPicker(
  p: Post,
  pick: (reaction: string) => void
): void {
  const list = settings.reactions.list;
  const mine = p.current_user_reaction ? p.current_user_reaction.id : "";
  const layer = openLayer({
    kind: "sheet",
    label: "React",
    body: html`<div class="sheet">
      <div class="sheet-head">
        <div class="sheet-title">React to #${p.post_number}</div>
        <div class="sheet-sub">Pick one — pick it again to take it back.</div>
      </div>
      <div class="emoji-grid scroll" data-grid>
        ${list.map(
          (r) =>
            html`<button
              type="button"
              class="emoji-cell${r === mine ? " mine" : ""}"
              data-r="${r}"
              aria-label="${r.replace(/_/g, " ")}"
            >
              ${emojiImg(r, "emoji big")}
            </button>`
        )}
      </div>
    </div>`,
    softkeys: { left: "Close", center: "React", right: "" },
    focusSelector: ".emoji-cell.mine",
  });
  $$("[data-r]", layer.el).forEach((b) =>
    b.addEventListener("click", () => {
      const r = b.getAttribute("data-r") || "";
      layer.close();
      if (r) pick(r);
    })
  );
}

interface ReactionUsers {
  reaction_users?: Array<{
    id: string;
    count: number;
    users: Array<{ username: string; avatar_template: string }>;
  }>;
}

export function whoReacted(postId: number, only: string): void {
  const done = (items: SheetItem[], title: string) => {
    if (!items.length) toast("No one yet.");
    else actionSheet(title, items);
  };
  if (reactionsOn()) {
    get<ReactionUsers>(
      `/discourse-reactions/posts/${postId}/reactions-users.json`
    ).then(
      (d) => {
        const items: SheetItem[] = [];
        const groups = (d.reaction_users || []).filter(
          (g) => !only || g.id === only
        );
        for (let i = 0; i < groups.length; i++) {
          items.push({
            label: html`${emojiImg(groups[i].id)} ${groups[i].count}`,
            heading: true,
          });
          for (let k = 0; k < groups[i].users.length; k++) {
            const u = groups[i].users[k];
            items.push({
              label: html`${avatar(u.avatar_template, 20)} @${u.username}`,
              href: href(userPath(u.username)),
            });
          }
        }
        done(items, "Reactions");
      },
      (e: unknown) => toast(errorMessage(e), "error")
    );
    return;
  }
  get<{
    post_action_users?: Array<{ username: string; avatar_template: string }>;
  }>(`/post_action_users.json?id=${postId}&post_action_type_id=${LIKE}`).then(
    (d) => {
      const items: SheetItem[] = (d.post_action_users || []).map((u) => ({
        label: html`${avatar(u.avatar_template, 20)} @${u.username}`,
        href: href(userPath(u.username)),
      }));
      done(items, "Liked by");
    },
    (e: unknown) => toast(errorMessage(e), "error")
  );
}
