// Bookmarks, messages and drafts — the "my stuff" lists.

import { errorMessage } from "../api.ts";
import { go } from "../app.ts";
import { swr } from "../cache.ts";
import { emojify } from "../content/emoji.ts";
import { clearDraft, listDrafts, type Draft } from "../drafts.ts";
import { timeAgo, truncate } from "../format.ts";
import { html, type SafeHtml } from "../html.ts";
import { focusContent } from "../nav.ts";
import { href, type RouteContext } from "../router.ts";
import { user } from "../session.ts";
import { avatar, topicPath } from "../site.ts";
import type { TopicListResponse } from "../types.ts";
import { icon } from "../ui/icons.ts";
import { actionSheet, confirmDialog } from "../ui/layers.ts";
import { decodeEntities, topicRow, usersById } from "../ui/topic-row.ts";
import { useScreen } from "./common.ts";
import { openComposer } from "./composer.ts";

interface Bookmark {
  id: number;
  title?: string;
  fancy_title?: string;
  excerpt?: string;
  bookmarkable_type: string;
  bookmarkable_url?: string;
  topic_id?: number;
  linked_post_number?: number;
  slug?: string;
  created_at: string;
  user?: { username: string; avatar_template: string };
  name?: string | null;
  reminder_at?: string | null;
}

export function bookmarksRoute(ctx: RouteContext): Promise<void> {
  const s = useScreen();
  s.title("Bookmarks", { back: true });
  s.loading();
  const u = user;
  if (!u) return Promise.resolve();
  let first = true;
  return swr<{
    user_bookmark_list?: { bookmarks: Bookmark[] };
    bookmarks?: Bookmark[];
  }>(`/u/${encodeURIComponent(u.username)}/bookmarks.json`, (d) => {
    const list =
      (d.user_bookmark_list && d.user_bookmark_list.bookmarks) ||
      d.bookmarks ||
      [];
    if (!list.length) {
      s.empty("No bookmarks.", "bookmark");
      return;
    }
    const rows: SafeHtml[] = list.map((b) => {
      const title = decodeEntities(b.fancy_title || b.title || "Bookmark");
      const path = b.topic_id
        ? topicPath(b.topic_id, b.slug || "", b.linked_post_number || null)
        : "/bookmarks";
      return html`<li>
        <a class="row" href="${href(path)}" data-key="b${b.id}">
          ${b.user ? avatar(b.user.avatar_template, 28) : icon("bookmark")}
          <div class="row-main">
            <div class="row-title">${emojify(title)}</div>
            ${b.excerpt
              ? html`<div class="row-excerpt">
                  ${truncate(b.excerpt.replace(/<[^>]*>/g, ""), 140)}
                </div>`
              : ""}
            <div class="row-meta">
              ${b.name
                ? html`<span>${icon("tag", "m")}${b.name}</span>`
                : ""}${b.user
                ? html`<span>@${b.user.username}</span>`
                : ""}<span>saved ${timeAgo(b.created_at)}</span>${b.reminder_at
                ? html`<span>${icon("clock", "m")}reminder</span>`
                : ""}
            </div>
          </div></a
        >
      </li>`;
    });
    s.render(
      html`<ul class="rows">
        ${rows}
      </ul>`
    );
    if (first && !ctx.restore) focusContent(".row");
    first = false;
  }).catch((e: unknown) =>
    s.error(errorMessage(e), () => go(ctx.path, { replace: true }))
  );
}

export function messagesRoute(ctx: RouteContext): Promise<void> {
  const s = useScreen();
  const u = user;
  s.title("Messages", { back: true });
  if (!u) return Promise.resolve();
  const box =
    ctx.query.box === "sent"
      ? "sent"
      : ctx.query.box === "archive"
        ? "archive"
        : "inbox";
  const endpoint =
    box === "sent"
      ? `/topics/private-messages-sent/${encodeURIComponent(u.username)}.json`
      : box === "archive"
        ? `/topics/private-messages-archive/${encodeURIComponent(u.username)}.json`
        : `/topics/private-messages/${encodeURIComponent(u.username)}.json`;
  const newMessage = () => openComposer({ kind: "message" });
  if (u.can_send_private_messages) {
    s.compose("new-message", "New message");
    s.act("new-message", newMessage);
    s.keys({ "3": newMessage });
    s.softkeys({ right: { label: "New", run: newMessage } });
  }
  s.render(
    html`<nav class="tabs" data-tabs data-row>
        <a
          class="tab${box === "inbox" ? " on" : ""}"
          href="${href("/messages")}"
          data-tab="inbox"
          >Inbox</a
        >
        <a
          class="tab${box === "sent" ? " on" : ""}"
          href="${href("/messages?box=sent")}"
          data-tab="sent"
          >Sent</a
        >
        <a
          class="tab${box === "archive" ? " on" : ""}"
          href="${href("/messages?box=archive")}"
          data-tab="archive"
          >Archive</a
        >
      </nav>
      <ul id="pmList" class="rows">
        <li class="state state-loading">
          <span class="spinner"></span>Loading…
        </li>
      </ul>`
  );
  let first = true;
  return swr<TopicListResponse>(endpoint, (d) => {
    const list = document.getElementById("pmList");
    if (!list || !s.alive()) return;
    const topics = (d.topic_list && d.topic_list.topics) || [];
    const users = usersById(d.users);
    list.innerHTML = topics.length
      ? html`${topics.map((t) => topicRow(t, users, { excerpt: false }))}`.value
      : html`<li class="state state-empty">
          ${icon("mail")}
          <p>No messages here.</p>
        </li>`.value;
    if (first && !ctx.restore) focusContent(".row");
    first = false;
  }).catch((e: unknown) =>
    s.error(errorMessage(e), () =>
      go(ctx.path + location.search, { replace: true })
    )
  );
}

function draftTitle(d: Draft): string {
  if (d.kind === "reply")
    return "Reply: " + (d.topicTitle || `topic ${d.topicId}`);
  if (d.kind === "edit") return "Edit: " + (d.topicTitle || `post ${d.postId}`);
  if (d.kind === "topic") return d.title ? "Topic: " + d.title : "New topic";
  return d.title ? "Message: " + d.title : "New message";
}

export function draftsRoute(ctx: RouteContext): void {
  const s = useScreen();
  s.title("Drafts", { back: true });
  const drafts = listDrafts();
  if (!drafts.length) {
    s.empty("No drafts.", "draft");
    return;
  }
  s.render(
    html`<ul class="rows">
      ${drafts.map(
        (d) =>
          html`<li>
            <button
              type="button"
              class="row"
              data-act="open-draft"
              data-draft="${d.key}"
              data-key="d-${d.key}"
            >
              <span class="row-icon"
                >${icon(
                  d.kind === "reply"
                    ? "reply"
                    : d.kind === "edit"
                      ? "edit"
                      : d.kind === "message"
                        ? "mail"
                        : "plus"
                )}</span
              >
              <div class="row-main">
                <div class="row-title">${emojify(draftTitle(d))}</div>
                ${d.text
                  ? html`<div class="row-excerpt">
                      ${truncate(d.text, 120)}
                    </div>`
                  : ""}
                <div class="row-meta">
                  <span>${timeAgo(d.updatedAt)}</span>
                </div>
              </div>
            </button>
          </li>`
      )}
    </ul>`
  );

  const open = (d: Draft) => {
    if (d.kind === "reply" && d.topicId) {
      // Open the topic so the reply lands in context.
      go(topicPath(d.topicId, "", null) + "?compose=1");
    } else if (d.kind === "edit" && d.topicId && d.postId) {
      go(topicPath(d.topicId, "", null) + "?edit=" + d.postId);
    } else if (d.kind === "topic") {
      openComposer({ kind: "topic", categoryId: d.categoryId || null });
    } else {
      openComposer({ kind: "message" });
    }
  };

  s.act("open-draft", (el) => {
    const key = el.getAttribute("data-draft") || "";
    const d = drafts.filter((x) => x.key === key)[0];
    if (!d) return;
    actionSheet(draftTitle(d), [
      { label: "Continue writing", icon: "edit", run: () => open(d) },
      {
        label: "Discard",
        icon: "trash",
        danger: true,
        run: () =>
          confirmDialog("Throw away this draft?", {
            ok: "Discard",
            danger: true,
          }).then((ok) => {
            if (!ok) return;
            clearDraft(d.key);
            go("/drafts", { replace: true });
          }),
      },
    ]);
  });
  if (!ctx.restore) focusContent(".row");
}
