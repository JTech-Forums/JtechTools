// Notifications: what happened, who did it, and a tap to go there (which
// marks it read). Updates live.

import { errorMessage, get, put } from "../api.ts";
import { go } from "../app.ts";
import { settings } from "../config.ts";
import { appPathFor } from "../content/cooked.ts";
import { emojify, emojiImg } from "../content/emoji.ts";
import { appendHtml, byId } from "../dom.ts";
import { timeAgo } from "../format.ts";
import { html, safeUrl, type SafeHtml } from "../html.ts";
import { subscribe } from "../messagebus.ts";
import { focusContent } from "../nav.ts";
import { href, type RouteContext } from "../router.ts";
import { refreshUser, updateCounts, user } from "../session.ts";
import { inNativeApp, pushSettings } from "../push.ts";
import { avatar, notificationTypeName, topicPath, userPath } from "../site.ts";
import type { Notification } from "../types.ts";
import { icon } from "../ui/icons.ts";
import { actionSheet, toast } from "../ui/layers.ts";
import { decodeEntities } from "../ui/topic-row.ts";
import { useScreen } from "./common.ts";

interface Described {
  iconName: string;
  text: SafeHtml;
  path: string | null;
  external: string | null;
}

function who(n: Notification): string {
  const d = n.data;
  return String(
    d.display_username ||
      d.username ||
      d.original_username ||
      d.mentioned_by_username ||
      d.invited_by_username ||
      ""
  );
}

function topicTitle(n: Notification): string {
  const d = n.data;
  return decodeEntities(String(n.fancy_title || d.topic_title || ""));
}

function interpolate(template: string, data: Record<string, unknown>): string {
  return template.replace(
    /%\{(\w+)\}|\{\{(\w+)\}\}/g,
    (_m, a: string, b: string) => {
      const v = data[a || b];
      return v === undefined || v === null ? "" : String(v);
    }
  );
}

export function describe(n: Notification): Described {
  const type = notificationTypeName(n.notification_type);
  const d = n.data;
  const actor = who(n);
  const title = topicTitle(n);
  const topicLink = n.topic_id
    ? topicPath(n.topic_id, n.slug || "", n.post_number || null)
    : null;
  const t = (verb: string, withTitle = true) =>
    html`${actor ? html`<b>${actor}</b> ` : ""}${verb}${withTitle && title
      ? html` <span class="n-topic">${emojify(title)}</span>`
      : ""}`;

  switch (type) {
    case "mentioned":
      return {
        iconName: "chat",
        text: t("mentioned you in"),
        path: topicLink,
        external: null,
      };
    case "group_mentioned":
      return {
        iconName: "users",
        text: t(`mentioned @${d.group_name || "your group"} in`),
        path: topicLink,
        external: null,
      };
    case "replied":
      return {
        iconName: "reply",
        text: t("replied in"),
        path: topicLink,
        external: null,
      };
    case "quoted":
      return {
        iconName: "quote",
        text: t("quoted you in"),
        path: topicLink,
        external: null,
      };
    case "edited":
      return {
        iconName: "edit",
        text: t("edited your post in"),
        path: topicLink,
        external: null,
      };
    case "liked":
    case "liked_consolidated": {
      const count = Number(d.count || 0);
      if (type === "liked_consolidated") {
        return {
          iconName: "heart",
          text: t(`liked ${count} of your posts`, false),
          path: user ? userPath(user.username) : null,
          external: null,
        };
      }
      const others = d.username2
        ? html` and <b>${String(d.username2)}</b>`
        : count > 1
          ? html` and ${count - 1} others`
          : html``;
      return {
        iconName: "heart",
        text: html`<b>${actor}</b>${others} liked
          <span class="n-topic">${emojify(title)}</span>`,
        path: topicLink,
        external: null,
      };
    }
    case "reaction": {
      const r = String(d.reaction_icon || "");
      return {
        iconName: "smile",
        text: html`<b>${actor}</b> reacted ${r ? emojiImg(r) : ""} to
          <span class="n-topic">${emojify(title)}</span>`,
        path: topicLink,
        external: null,
      };
    }
    case "private_message":
      return {
        iconName: "mail",
        text: t("sent you a message:"),
        path: topicLink,
        external: null,
      };
    case "invited_to_private_message":
      return {
        iconName: "mail",
        text: t("invited you to a message:"),
        path: topicLink,
        external: null,
      };
    case "invited_to_topic":
      return {
        iconName: "users",
        text: t("invited you to"),
        path: topicLink,
        external: null,
      };
    case "invitee_accepted":
      return {
        iconName: "user",
        text: t("accepted your invitation", false),
        path: actor ? userPath(actor) : null,
        external: null,
      };
    case "posted":
    case "watching_first_post":
    case "watching_category_or_tag":
      return {
        iconName: "chat",
        text: t(type === "posted" ? "posted in" : "started"),
        path: topicLink,
        external: null,
      };
    case "moved_post":
      return {
        iconName: "jump",
        text: t("moved your post to"),
        path: topicLink,
        external: null,
      };
    case "linked":
    case "linked_consolidated":
      return {
        iconName: "link",
        text: t("linked to your post from"),
        path: topicLink,
        external: null,
      };
    case "granted_badge":
      return {
        iconName: "award",
        text: html`You earned the <b>${String(d.badge_name || "")}</b> badge`,
        path: user ? userPath(user.username) : null,
        external: null,
      };
    case "group_message_summary":
      return {
        iconName: "mail",
        text: html`${String(d.inbox_count || "")} messages in your
          <b>${String(d.group_name || "")}</b> inbox`,
        path: "/messages",
        external: null,
      };
    case "topic_reminder":
    case "bookmark_reminder":
      return {
        iconName: "bookmark",
        text: html`Reminder:
          <span class="n-topic"
            >${emojify(title || String(d.bookmark_name || ""))}</span
          >`,
        path: topicLink,
        external: null,
      };
    case "post_approved":
      return {
        iconName: "check",
        text: html`Your post was approved:
          <span class="n-topic">${emojify(title)}</span>`,
        path: topicLink,
        external: null,
      };
    case "membership_request_accepted":
      return {
        iconName: "users",
        text: html`You were accepted into <b>${String(d.group_name || "")}</b>`,
        path: null,
        external: null,
      };
    case "custom": {
      const key = String(d.message || "");
      const template = settings.notificationTexts[key];
      const text = template
        ? interpolate(template, d)
        : key && key.indexOf(".") < 0
          ? key
          : title || "Notification";
      const url = String(d.url || "");
      let path: string | null = null;
      if (d.reqpm)
        path =
          d.reqpm_kind === "shared" ? "/contacts?tab=contacts" : "/contacts";
      else if (url) path = appPathFor(url) || (n.topic_id ? topicLink : null);
      else path = topicLink;
      return {
        iconName: d.reqpm ? "phone" : "bell",
        text: html`${actor && template && template.indexOf("%{") < 0
          ? html`<b>${actor}</b> `
          : ""}${emojify(text)}${title && text.indexOf(title) < 0 && !d.reqpm
          ? html` <span class="n-topic">${emojify(title)}</span>`
          : ""}`,
        path,
        external: !path && url ? url : null,
      };
    }
    default: {
      const text =
        title ||
        String(d.message || d.title || "") ||
        type.replace(/_/g, " ") ||
        "Notification";
      return {
        iconName: "bell",
        text: html`${actor ? html`<b>${actor}</b> · ` : ""}${emojify(text)}`,
        path: topicLink,
        external: null,
      };
    }
  }
}

function row(n: Notification): SafeHtml {
  const d = describe(n);
  const avatarTemplate =
    n.acting_user_avatar_template || (n.data.avatar_template as string) || "";
  // External targets only as http(s)/mailto — never javascript: and friends.
  const target = d.path
    ? href(d.path)
    : d.external && safeUrl(d.external) !== "#"
      ? safeUrl(d.external)
      : href("/notifications");
  return html`<li>
    <a
      class="row notif${n.read ? "" : " unread"}${n.high_priority && !n.read
        ? " high"
        : ""}"
      href="${target}"
      data-key="n${n.id}"
      data-act="open-notification"
      data-id="${n.id}"
      data-read="${n.read ? "1" : "0"}"
      ${d.external ? html` data-external="1"` : ""}
    >
      <span class="row-icon"
        >${avatarTemplate ? avatar(avatarTemplate, 28) : icon(d.iconName)}</span
      >
      <div class="row-main">
        <div class="n-text">${d.text}</div>
        <div class="row-meta">
          <span>${icon(d.iconName, "m")}${timeAgo(n.created_at)}</span>
        </div>
      </div>
    </a>
  </li>`;
}

export function notificationsRoute(ctx: RouteContext): Promise<void> {
  const s = useScreen();
  const filter = ctx.query.filter === "unread" ? "unread" : "all";
  s.title("Notifications", { back: true });
  s.render(
    html`<nav class="tabs" data-tabs data-row>
        <a
          class="tab${filter === "all" ? " on" : ""}"
          href="${href("/notifications")}"
          data-tab="all"
          >All</a
        >
        <a
          class="tab${filter === "unread" ? " on" : ""}"
          href="${href("/notifications?filter=unread")}"
          data-tab="unread"
          >Unread</a
        >
      </nav>
      <ul id="notifList" class="rows">
        <li class="state state-loading">
          <span class="spinner"></span>Loading…
        </li>
      </ul>
      <div id="notifFoot" class="list-foot"></div>`
  );

  let offset = 0;
  let more = false;
  const list = byId("notifList") as HTMLElement;
  const foot = byId("notifFoot") as HTMLElement;

  const load = (append: boolean): Promise<void> =>
    get<{
      notifications?: Notification[];
      total_rows_notifications?: number;
      load_more_notifications?: string;
    }>(
      `/notifications.json?limit=30&offset=${offset}${filter === "unread" ? "&filter=unread" : ""}`
    ).then((d) => {
      if (!s.alive()) return;
      const items = d.notifications || [];
      const rows = items.map(row);
      offset += items.length;
      more =
        !!d.load_more_notifications &&
        items.length > 0 &&
        (!d.total_rows_notifications || offset < d.total_rows_notifications);
      if (!append) {
        list.innerHTML = rows.length
          ? html`${rows}`.value
          : html`<li class="state state-empty">
              ${icon("bell")}
              <p>
                ${filter === "unread"
                  ? "No unread notifications."
                  : "No notifications yet."}
              </p>
            </li>`.value;
      } else {
        appendHtml(list, html`${rows}`);
      }
      foot.innerHTML = more
        ? html`<button
            type="button"
            class="btn block"
            data-act="more-notifications"
          >
            Load more
          </button>`.value
        : "";
    });

  s.act("more-notifications", () => {
    load(true).catch((e: unknown) => toast(errorMessage(e), "error"));
  });
  s.act("open-notification", (el, e) => {
    const id = parseInt(el.getAttribute("data-id") || "0", 10);
    if (el.getAttribute("data-read") === "0") {
      el.setAttribute("data-read", "1");
      el.classList.remove("unread");
      put("/notifications/mark-read.json", { id }).then(
        () => refreshUser(),
        () => undefined
      );
    }
    if (el.getAttribute("data-external") === "1") {
      window.open(el.getAttribute("href") || "", "_blank");
    } else {
      go(el.getAttribute("href") || "/");
    }
    e.preventDefault();
  });

  const markAll = () =>
    put("/notifications/mark-read.json").then(
      () => {
        updateCounts({
          unread_notifications: 0,
          unread_high_priority_notifications: 0,
          all_unread_notifications_count: 0,
        });
        toast("All marked as read.", "success");
        go(ctx.path + location.search, { replace: true });
      },
      (e: unknown) => toast(errorMessage(e), "error")
    );

  const options = () =>
    actionSheet("Notifications", [
      { label: "Mark all as read", icon: "check", run: () => void markAll() },
      {
        label: "Refresh",
        icon: "refresh",
        run: () => go(ctx.path + location.search, { replace: true }),
      },
      { label: "Preferences", icon: "gear", href: href("/preferences") },
      ...(inNativeApp() && settings.pushEnabled
        ? [{ label: "Push notifications…", icon: "bell", run: pushSettings }]
        : []),
    ]);
  s.softkeys({ right: { label: "Options", run: options } });
  s.keys({
    "9": options,
    "5": () => go(ctx.path + location.search, { replace: true }),
  });

  if (user) {
    s.onLeave(
      subscribe(`/notification/${user.id}`, () => {
        offset = 0;
        load(false).catch(() => undefined);
      })
    );
  }

  return load(false).then(
    () => {
      if (!ctx.restore) focusContent(".row");
    },
    (e: unknown) =>
      s.error(errorMessage(e), () =>
        go(ctx.path + location.search, { replace: true })
      )
  );
}
