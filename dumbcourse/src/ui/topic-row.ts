// One topic in a list: title, category, counts and who's talking. Unread
// topics are bold with a coloured edge and open at the first unread post.

import { settings } from "../config.ts";
import { emojify } from "../content/emoji.ts";
import { count, timeAgo } from "../format.ts";
import { html, raw, type SafeHtml } from "../html.ts";
import { prefs } from "../prefs.ts";
import { avatar, categoryBadge, topicHref } from "../site.ts";
import type { BasicUser, TopicListItem } from "../types.ts";
import { icon } from "./icons.ts";

export function isUnread(t: TopicListItem): boolean {
  if (t.unseen) return true;
  if ((t.unread_posts || 0) > 0 || (t.new_posts || 0) > 0) return true;
  return false;
}

// Discourse sends new_posts as an old alias of unread_posts (the same
// number), so adding them counted every unread post twice.
export function unreadCount(t: TopicListItem): number {
  return Math.max(t.unread_posts || 0, t.new_posts || 0);
}

// Where tapping a topic should land: the first post you haven't read.
export function entryPost(t: TopicListItem): number | null {
  if (t.unseen) return null;
  const last = t.last_read_post_number || 0;
  if (last && last < t.highest_post_number) return last + 1;
  if (last) return last;
  return null;
}

function showPosters(): boolean {
  if (!prefs.avatars) return false;
  const v = settings.topicPostersVisibility;
  if (v === "none") return false;
  if (v === "all") return true;
  const small = (window.innerWidth || 400) <= 520;
  return v === "mobile" ? small : !small;
}

function tagName(tag: string | { name: string }): string {
  return typeof tag === "string" ? tag : tag.name;
}

export function topicRow(
  t: TopicListItem,
  users: Record<number, BasicUser>,
  opts: { excerpt?: boolean } = {}
): SafeHtml {
  const unread = isUnread(t);
  const n = unreadCount(t);
  const replies = Math.max(0, (t.posts_count || 1) - 1);
  const title = emojify(
    t.fancy_title ? decodeEntities(t.fancy_title) : t.title
  );
  const status: SafeHtml[] = [];
  if (t.pinned) status.push(icon("pin", "st"));
  if (t.closed) status.push(icon("lock", "st"));
  if (t.archived) status.push(icon("archive", "st"));
  if (t.bookmarked) status.push(icon("bookmarkOn", "st st-on"));

  let posters = html``;
  if (showPosters() && t.posters && t.posters.length) {
    const faces: SafeHtml[] = [];
    for (let i = 0; i < t.posters.length && faces.length < 3; i++) {
      const u = users[t.posters[i].user_id];
      if (u) faces.push(avatar(u.avatar_template, 22, "avatar mini"));
    }
    if (faces.length) posters = html`<span class="posters">${faces}</span>`;
  }

  const tags =
    settings.tagsEnabled && t.tags && t.tags.length
      ? html`${t.tags
          .slice(0, 3)
          .map((tag) => html`<span class="tag">${tagName(tag)}</span>`)}`
      : html``;
  const excerpt =
    opts.excerpt !== false && prefs.excerpts && t.excerpt
      ? html`<div class="row-excerpt">${raw(t.excerpt)}</div>`
      : html``;
  const label = `${t.title}${unread ? (t.unseen ? ", new" : `, ${n} unread`) : ""}, ${replies} replies`;

  return html`<li>
    <a
      class="row topic${unread ? " unread" : ""}"
      href="${topicHref(t.id, t.slug, entryPost(t))}"
      data-key="t${t.id}"
      data-topic="${t.id}"
      aria-label="${label}"
    >
      <div class="row-main">
        <div class="row-title">
          ${status.length
            ? html`<span class="status">${status}</span>`
            : ""}${title}
        </div>
        <div class="row-meta">
          ${categoryBadge(t.category_id)}${tags}<span>${icon(
            "chat",
            "m"
          )}${count(replies)}</span>${t.like_count
            ? html`<span>${icon("heart", "m")}${count(t.like_count)}</span>`
            : ""}<span>${timeAgo(
            t.last_posted_at || t.created_at
          )}</span>${t.unseen
            ? html`<span class="pill new">New</span>`
            : n > 0
              ? html`<span class="pill">${n}</span>`
              : ""}
        </div>
        ${excerpt}
      </div>
      ${posters}
    </a>
  </li>`;
}

let decoder: HTMLTextAreaElement | null = null;

// Discourse sends fancy_title HTML-escaped (with typographic entities like
// &ldquo;); decode it here and let html`` escape it again. A textarea never
// runs or loads anything put into it.
export function decodeEntities(s: string): string {
  if (!decoder) decoder = document.createElement("textarea");
  decoder.innerHTML = String(s || "").replace(/</g, "&lt;");
  return decoder.value;
}

export function usersById(
  list: BasicUser[] | undefined
): Record<number, BasicUser> {
  const out: Record<number, BasicUser> = {};
  if (list) for (let i = 0; i < list.length; i++) out[list[i].id] = list[i];
  return out;
}
