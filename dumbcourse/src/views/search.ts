// Search: posts with the matching snippet, people and categories, with
// quick filters and your recent searches.

import { errorMessage, get } from "../api.ts";
import { go } from "../app.ts";
import { emojify } from "../content/emoji.ts";
import { $, appendHtml, byId } from "../dom.ts";
import { timeAgo } from "../format.ts";
import { escapeHtml, html, raw, type SafeHtml } from "../html.ts";
import { focus, focusContent } from "../nav.ts";
import { buildQuery, href, type RouteContext } from "../router.ts";
import {
  addCategories,
  avatar,
  categoryBadge,
  categoryPath,
  topicPath,
  userPath,
} from "../site.ts";
import { userGet, userSet } from "../storage.ts";
import { icon } from "../ui/icons.ts";
import { actionSheet, toast } from "../ui/layers.ts";
import { decodeEntities } from "../ui/topic-row.ts";
import { useScreen } from "./common.ts";

interface SearchPost {
  id: number;
  username: string;
  avatar_template: string;
  blurb: string;
  topic_id: number;
  post_number: number;
  created_at: string;
  like_count?: number;
}

interface SearchTopic {
  id: number;
  title: string;
  fancy_title?: string;
  slug: string;
  category_id?: number;
  posts_count?: number;
  closed?: boolean;
}

interface SearchResult {
  posts?: SearchPost[];
  topics?: SearchTopic[];
  users?: Array<{ username: string; name?: string; avatar_template: string }>;
  categories?: Array<{
    id: number;
    name: string;
    slug: string;
    color: string;
    parent_category_id?: number | null;
  }>;
  grouped_search_result?: {
    more_full_page_results?: boolean;
    more_posts?: boolean;
  };
}

const FILTERS = [
  { label: "Titles only", token: "in:title" },
  { label: "Newest first", token: "order:latest" },
  { label: "Most liked", token: "order:likes" },
  { label: "Open topics", token: "status:open" },
  { label: "Solved", token: "status:solved" },
  { label: "My posts", token: "@me" },
  { label: "My bookmarks", token: "in:bookmarks" },
  { label: "Topics I've seen", token: "in:seen" },
  { label: "Last 7 days", token: "after:" + isoDaysAgo(7) },
];

function isoDaysAgo(days: number): string {
  const d = new Date(Date.now() - days * 86400000);
  const m = d.getMonth() + 1;
  const day = d.getDate();
  return (
    d.getFullYear() +
    "-" +
    (m < 10 ? "0" : "") +
    m +
    "-" +
    (day < 10 ? "0" : "") +
    day
  );
}

// Marks the words you searched for. The text is split on the matches
// first and each piece escaped on its own, so a match can never cut an
// HTML entity in half.
export function highlight(text: string, query: string): SafeHtml {
  const words = query
    .split(/\s+/)
    .filter(
      (w) =>
        w.length > 1 &&
        w.indexOf(":") < 0 &&
        w.charAt(0) !== "@" &&
        w.charAt(0) !== "#"
    )
    .map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  if (!words.length) return raw(escapeHtml(text));
  const re = new RegExp("(" + words.join("|") + ")", "gi");
  const parts = text.split(re);
  let out = "";
  for (let i = 0; i < parts.length; i++) {
    // split() with a capture group puts the matches at odd indexes.
    out +=
      i % 2
        ? "<mark>" + escapeHtml(parts[i]) + "</mark>"
        : escapeHtml(parts[i]);
  }
  return raw(out);
}

function recent(): string[] {
  return userGet<string[]>("recent-searches", []);
}

function remember(q: string): void {
  const list = recent().filter((x) => x !== q);
  list.unshift(q);
  userSet("recent-searches", list.slice(0, 8));
}

export function searchRoute(ctx: RouteContext): Promise<void> | void {
  const s = useScreen();
  const q = (ctx.query.q || "").replace(/^\s+|\s+$/g, "");
  s.title("Search", { back: true });
  s.render(
    html`<form class="search-form" data-search data-row role="search">
        <label class="sr" for="searchInput">Search</label>
        <input
          id="searchInput"
          type="search"
          value="${q}"
          placeholder="Search the forum"
          autocomplete="off"
          enterkeyhint="search"
        />
        <button type="submit" class="btn primary icon-only" aria-label="Search">
          ${icon("search")}
        </button>
      </form>
      <div class="tabs" data-row id="filterRow">
        <button type="button" class="tab" data-act="search-filters">
          ${icon("format", "m")}Filters
        </button>
        ${q
          ? html`<button type="button" class="tab" data-act="search-clear">
              Clear
            </button>`
          : ""}
      </div>
      <div id="results"></div>`
  );

  const form = $("[data-search]") as HTMLFormElement;
  const input = byId("searchInput") as HTMLInputElement;
  const results = byId("results") as HTMLElement;
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const value = input.value.replace(/^\s+|\s+$/g, "");
    if (value.length < 2) {
      toast("Type at least 2 characters.");
      return;
    }
    go("/search" + buildQuery({ q: value }), { replace: !!q });
  });

  s.act("search-clear", () => go("/search", { replace: true }));
  s.act("search-filters", () => {
    actionSheet(
      "Filter the search",
      FILTERS.map((f) => ({
        label: f.label,
        active: input.value.indexOf(f.token) >= 0,
        run: () => {
          const has = input.value.indexOf(f.token) >= 0;
          const value = has
            ? input.value.replace(f.token, "").replace(/\s{2,}/g, " ")
            : (input.value + " " + f.token).replace(/^\s+/, "");
          input.value = value;
          if (value.replace(/\s+/g, "").length >= 2)
            go("/search" + buildQuery({ q: value.replace(/^\s+|\s+$/g, "") }), {
              replace: true,
            });
          else focus(input);
        },
      }))
    );
  });

  if (!q) {
    const list = recent();
    results.innerHTML = list.length
      ? html`<h2 class="section-title">Recent searches</h2>
          <ul class="rows">
            ${list.map(
              (r) =>
                html`<li>
                  <a
                    class="row"
                    href="${href("/search" + buildQuery({ q: r }))}"
                    data-key="r-${r}"
                    ><span class="row-icon">${icon("clock")}</span>
                    <div class="row-main">${r}</div></a
                  >
                </li>`
            )}
          </ul>
          <p class="hint pad">Tip: press # anywhere to search.</p>`.value
      : html`<div class="state state-empty">
          ${icon("search")}
          <p>Find topics, posts and people. Filters narrow it down.</p>
        </div>`.value;
    requestAnimationFrame(() => focus(input));
    return;
  }

  remember(q);
  let page = 1;
  results.innerHTML =
    '<div class="state state-loading"><span class="spinner"></span>Searching…</div>';

  const render = (d: SearchResult, append: boolean) => {
    if (d.categories) addCategories(d.categories as never);
    const topics: Record<number, SearchTopic> = {};
    (d.topics || []).forEach((t) => (topics[t.id] = t));
    const parts: SafeHtml[] = [];
    if (!append && d.users && d.users.length) {
      parts.push(
        html`<h2 class="section-title">People</h2>
          <ul class="rows">
            ${d.users.slice(0, 5).map(
              (u) =>
                html`<li>
                  <a
                    class="row"
                    href="${href(userPath(u.username))}"
                    data-key="u-${u.username}"
                    >${avatar(u.avatar_template, 28)}
                    <div class="row-main">
                      <div class="row-title">${u.name || u.username}</div>
                      <div class="row-meta">@${u.username}</div>
                    </div></a
                  >
                </li>`
            )}
          </ul>`
      );
    }
    if (!append && d.categories && d.categories.length) {
      parts.push(
        html`<h2 class="section-title">Categories</h2>
          <ul class="rows">
            ${d.categories.slice(0, 5).map(
              (c) =>
                html`<li>
                  <a
                    class="row"
                    href="${href(categoryPath(c as never))}"
                    data-key="c-${c.id}"
                    ><div class="row-main">${categoryBadge(c.id)}</div></a
                  >
                </li>`
            )}
          </ul>`
      );
    }
    const posts = d.posts || [];
    if (posts.length) {
      const rows = posts.map((p) => {
        const t = topics[p.topic_id];
        const title = t ? decodeEntities(t.fancy_title || t.title) : "Topic";
        return html`<li>
          <a
            class="row result"
            href="${href(
              topicPath(p.topic_id, t ? t.slug : "", p.post_number)
            )}"
            data-key="s-${p.id}"
          >
            <div class="row-main">
              <div class="row-title">${emojify(title)}</div>
              <div class="row-excerpt">
                ${highlight(decodeEntities(p.blurb.replace(/<[^>]*>/g, "")), q)}
              </div>
              <div class="row-meta">
                ${t ? categoryBadge(t.category_id) : ""}<span
                  >@${p.username}</span
                ><span>${timeAgo(p.created_at)}</span>${p.post_number > 1
                  ? html`<span>#${p.post_number}</span>`
                  : ""}
              </div>
            </div></a
          >
        </li>`;
      });
      parts.push(
        append
          ? html`${rows}`
          : html`<h2 class="section-title">Posts</h2>
              <ul class="rows" id="postResults">
                ${rows}
              </ul>`
      );
    }
    const more = !!(
      d.grouped_search_result &&
      (d.grouped_search_result.more_full_page_results ||
        d.grouped_search_result.more_posts)
    );
    if (append) {
      const ul = byId("postResults");
      if (ul) appendHtml(ul, html`${parts}`);
    } else if (!parts.length) {
      results.innerHTML = html`<div class="state state-empty">
        ${icon("search")}
        <p>Nothing found for “${q}”.</p>
      </div>`.value;
    } else {
      results.innerHTML = html`${parts}
        <div id="searchMore" class="list-foot"></div>`.value;
    }
    const foot = byId("searchMore");
    if (foot)
      foot.innerHTML = more
        ? html`<button type="button" class="btn block" data-act="search-more">
            More results
          </button>`.value
        : "";
  };

  s.act("search-more", () => {
    page++;
    get<SearchResult>(
      `/search.json?q=${encodeURIComponent(q)}&page=${page}`
    ).then(
      (d) => s.alive() && render(d, true),
      (e: unknown) => toast(errorMessage(e), "error")
    );
  });

  return get<SearchResult>(`/search.json?q=${encodeURIComponent(q)}`).then(
    (d) => {
      if (!s.alive()) return;
      render(d, false);
      if (!ctx.restore) focusContent(".row");
    },
    (e: unknown) => {
      if (!s.alive()) return;
      results.innerHTML = html`<div class="state state-error">
        ${icon("info")}
        <p>${errorMessage(e)}</p>
      </div>`.value;
    }
  );
}
