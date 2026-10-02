// Prepares a post's HTML (already sanitised by Discourse) for a small
// screen: forum links open inside Dumbcourse, outside links open in a new
// window, images honour the data-saver setting, embeds become plain links,
// and every link is collected so the post's action sheet can list them —
// much easier with a D-pad than tabbing through a paragraph.

import { closest } from "../compat.ts";
import { APP_ROOT, settings } from "../config.ts";
import { raw, type SafeHtml } from "../html.ts";
import { prefs } from "../prefs.ts";
import { dateTime, longDate, parseDate } from "../format.ts";

export interface PostLink {
  text: string;
  href: string;
  internal: boolean;
  // A picture in the post: href is its full-size original.
  image?: boolean;
}

export interface Processed {
  html: SafeHtml;
  links: PostLink[];
  images: number;
}

let inert: Document | null = null;

// Parsing into a separate document keeps the browser from fetching images
// we may decide not to show.
function scratch(): HTMLElement {
  if (!inert) {
    try {
      inert = document.implementation.createHTMLDocument("");
    } catch {
      inert = document;
    }
  }
  return inert.createElement("div");
}

function all(root: Element, selector: string): Element[] {
  const list = root.querySelectorAll(selector);
  const out: Element[] = [];
  for (let i = 0; i < list.length; i++) out.push(list[i]);
  return out;
}

function origin(): string {
  return location.protocol + "//" + location.host;
}

// A forum URL (relative or absolute on this host) → the matching
// Dumbcourse path, or null if Dumbcourse has no screen for it.
export function appPathFor(url: string): string | null {
  let u = url;
  if (u.indexOf(origin()) === 0) u = u.slice(origin().length);
  if (u.indexOf("//") === 0 || /^[a-z][a-z0-9+.-]*:/i.test(u)) return null;
  if (u.charAt(0) !== "/") return null;
  if (settings.subfolder && u.indexOf(settings.subfolder + "/") === 0)
    u = u.slice(settings.subfolder.length);
  if (u.indexOf(settings.basePath + "/") === 0 || u === settings.basePath)
    return u.slice(settings.basePath.length) || "/";
  const path = u.split("#")[0];
  if (
    /^\/(t|u|c|tag|tags|search|latest|new|unread|top|hot|categories|notifications|my\/(bookmarks|messages|activity))(\/|\?|$)/.test(
      path
    )
  ) {
    return path
      .replace(/^\/my\/bookmarks/, "/bookmarks")
      .replace(/^\/my\/messages/, "/messages")
      .replace(/^\/my\/activity/, "/u/me");
  }
  if (path === "/" || path === "") return "/";
  return null;
}

function absolute(url: string): string {
  if (/^https?:\/\//i.test(url) || url.indexOf("//") === 0) return url;
  if (url.charAt(0) === "/") return url;
  return url;
}

function linkText(a: Element): string {
  const text = (a.textContent || "")
    .replace(/\s+/g, " ")
    .replace(/^\s+|\s+$/g, "");
  if (text) return text.length > 80 ? text.slice(0, 79) + "…" : text;
  const img = a.querySelector("img");
  return (
    (img && (img.getAttribute("alt") || img.getAttribute("title"))) || "Link"
  );
}

function isEmojiOrAvatar(img: Element): boolean {
  const cls = " " + (img.getAttribute("class") || "") + " ";
  return (
    cls.indexOf(" emoji ") >= 0 ||
    cls.indexOf(" avatar ") >= 0 ||
    cls.indexOf(" site-icon ") >= 0
  );
}

function formatLocalDate(el: Element): void {
  const date = el.getAttribute("data-date");
  const time = el.getAttribute("data-time");
  if (!date) return;
  const iso =
    date +
    "T" +
    (time || "00:00:00") +
    (el.getAttribute("data-timezone") ? "" : "Z");
  let d = parseDate(iso);
  const tz = el.getAttribute("data-timezone");
  if (tz && d) {
    // Without Intl time-zone support we cannot convert; show it as written.
    d = parseDate(date + "T" + (time || "00:00:00"));
  }
  if (!d) return;
  el.textContent = time
    ? dateTime(d) + (tz ? " (" + tz + ")" : "")
    : longDate(d);
  el.setAttribute("class", "local-date");
}

export function processCooked(cooked: string | null | undefined): Processed {
  const box = scratch();
  box.innerHTML = cooked || "";
  const links: PostLink[] = [];
  let images = 0;

  // Embeds that cannot play on a flip phone become plain links.
  for (const frame of all(box, "iframe")) {
    const src = frame.getAttribute("src") || "";
    const a = box.ownerDocument.createElement("a");
    a.setAttribute("href", src);
    a.textContent = "▶ Open embedded content";
    if (frame.parentNode) frame.parentNode.replaceChild(a, frame);
  }
  for (const lazy of all(box, ".lazy-video-container, .lazyYT")) {
    const url =
      lazy.getAttribute("data-video-url") ||
      lazy.querySelector("a")?.getAttribute("href") ||
      "";
    const title = lazy.getAttribute("data-video-title") || "Video";
    if (!url) continue;
    const a = box.ownerDocument.createElement("a");
    a.setAttribute("href", url);
    a.setAttribute("class", "video-link");
    a.textContent = "▶ " + title;
    if (lazy.parentNode) lazy.parentNode.replaceChild(a, lazy);
  }

  // Lightbox chrome is for big screens.
  for (const meta of all(
    box,
    ".lightbox-wrapper .meta, .onebox-metadata, .quote-controls, .cooked-selection-barrier"
  )) {
    if (meta.parentNode) meta.parentNode.removeChild(meta);
  }

  // Images.
  for (const img of all(box, "img")) {
    img.removeAttribute("srcset");
    img.removeAttribute("sizes");
    const src = img.getAttribute("src") || "";
    if (isEmojiOrAvatar(img)) {
      img.setAttribute("loading", "lazy");
      continue;
    }
    images++;
    img.setAttribute("loading", "lazy");
    img.setAttribute("src", absolute(src));
    // A post is one D-pad stop, so pictures open from its menu: the full-size
    // original (the lightbox link around a resized picture), or the picture.
    // Link previews' thumbnails aren't the post's own pictures.
    if (!closest(img, ".onebox")) {
      const box = img.parentNode as Element | null;
      const full =
        box &&
        box.getAttribute &&
        /\blightbox\b/.test(box.getAttribute("class") || "")
          ? box.getAttribute("href") || src
          : src;
      const alt = (img.getAttribute("alt") || "").replace(/^\s+|\s+$/g, "");
      let pictures = 1;
      for (let i = 0; i < links.length; i++) if (links[i].image) pictures++;
      links.push({
        // Pasted pictures are all called "image", and phone photos are named
        // with digits; number those instead.
        text:
          /[a-z]/i.test(alt) && !/^image$/i.test(alt)
            ? alt.slice(0, 60)
            : "Picture " + pictures,
        href: absolute(full),
        internal: false,
        image: true,
      });
    }
    if (prefs.images === "show") continue;
    const w = img.getAttribute("width");
    const h = img.getAttribute("height");
    const alt = img.getAttribute("alt") || "";
    const btn = box.ownerDocument.createElement("button");
    btn.setAttribute("type", "button");
    btn.setAttribute("class", "img-placeholder");
    btn.setAttribute("data-act", "load-image");
    btn.setAttribute("data-src", absolute(src));
    if (w) btn.setAttribute("data-w", w);
    if (h) btn.setAttribute("data-h", h);
    btn.textContent =
      prefs.images === "tap"
        ? "Show image" +
          (alt && !/^image$/i.test(alt) ? ": " + alt.slice(0, 40) : "")
        : "Image hidden";
    const lightbox =
      img.parentNode &&
      (img.parentNode as Element).getAttribute &&
      (img.parentNode as Element).getAttribute("class") === "lightbox"
        ? img.parentNode
        : null;
    const target = lightbox || img;
    if (target.parentNode) target.parentNode.replaceChild(btn, target);
  }

  // Links.
  for (const a of all(box, "a[href]")) {
    const hrefValue = a.getAttribute("href") || "";
    if (!hrefValue || hrefValue.charAt(0) === "#") continue;
    if (/^javascript:/i.test(hrefValue)) {
      a.removeAttribute("href");
      continue;
    }
    const appPath = appPathFor(hrefValue);
    if (appPath) {
      a.setAttribute("href", APP_ROOT + (appPath === "/" ? "/" : appPath));
      a.removeAttribute("target");
      links.push({
        text: linkText(a),
        href: APP_ROOT + appPath,
        internal: true,
      });
    } else {
      const abs = absolute(hrefValue);
      a.setAttribute("href", abs);
      a.setAttribute("target", "_blank");
      a.setAttribute("rel", "noopener noreferrer nofollow ugc");
      if (
        !/^(mailto|tel|sms):/i.test(abs) &&
        !(a.getAttribute("class") || "").match(/lightbox/)
      ) {
        links.push({ text: linkText(a), href: abs, internal: false });
      } else if (/^(mailto|tel|sms):/i.test(abs)) {
        links.push({ text: linkText(a), href: abs, internal: false });
      }
    }
    // Links inside a post are reached through the post's action sheet, so
    // they do not add D-pad stops in the text.
    a.setAttribute("tabindex", "-1");
  }

  // Quotes: make the header jump to the quoted post.
  for (const quote of all(box, "aside.quote")) {
    const topic = quote.getAttribute("data-topic");
    const post = quote.getAttribute("data-post");
    const title = quote.querySelector(".title");
    if (title && topic && !title.querySelector("a")) {
      const a = box.ownerDocument.createElement("a");
      a.setAttribute("href", APP_ROOT + "/t/" + topic + "/" + (post || "1"));
      a.setAttribute("tabindex", "-1");
      a.setAttribute("class", "quote-jump");
      while (title.firstChild) a.appendChild(title.firstChild);
      title.appendChild(a);
    }
  }

  for (const el of all(box, ".discourse-local-date, span[data-date]"))
    formatLocalDate(el);

  for (const table of all(box, "table")) {
    const wrap = box.ownerDocument.createElement("div");
    wrap.setAttribute("class", "table-wrap");
    if (table.parentNode) {
      table.parentNode.replaceChild(wrap, table);
      wrap.appendChild(table);
    }
  }

  // Spoilers and details need to be operable without a mouse.
  for (const el of all(box, ".spoiler, .spoiled, .spoiler-blurred")) {
    el.setAttribute("data-act", "spoiler");
    el.setAttribute("role", "button");
  }
  for (const s of all(box, "details > summary"))
    s.setAttribute("tabindex", "-1");

  // Polls are drawn from post.polls instead (see polls.ts).
  for (const poll of all(box, "div.poll")) {
    const name = poll.getAttribute("data-poll-name") || "poll";
    const holder = box.ownerDocument.createElement("div");
    holder.setAttribute("class", "poll-slot");
    holder.setAttribute("data-poll-slot", name);
    if (poll.parentNode) poll.parentNode.replaceChild(holder, poll);
  }

  return { html: raw(box.innerHTML), links, images };
}

// Plain text of a post for quoting when the raw source is unavailable.
export function cookedToText(cooked: string): string {
  const box = scratch();
  box.innerHTML = cooked
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|li|h\d|blockquote)>/gi, "\n");
  return (box.textContent || "")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/^\s+|\s+$/g, "");
}
