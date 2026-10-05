import { getAbsoluteURL } from "discourse/lib/get-url";

export interface PrintTopic {
  title: string;
  url: string;
}

export interface PrintPost {
  cooked: string;
  username: string;
  name?: string;
  created_at: string;
}

// How long stylesheets and images get to load before printing anyway.
const LOAD_TIMEOUT = 8000;

// Prints a topic's first post on its own (setting print_button_categories),
// which core's print view can't: it prints the whole topic and ignores the
// post filters. The page is built in a hidden frame from the post's cooked
// HTML and the forum's own stylesheets, so it looks like the post, and the
// theme's print palette turns a dark mode light on paper. A frame rather than
// a new tab: pop-up blockers (and some phone browsers' in-app views) refuse
// new windows, and the print dialog is where "Save as PDF" is anyway.
export function printPost(
  post: PrintPost,
  topic: PrintTopic,
  siteTitle: string
) {
  document.querySelector(".jt-print-frame")?.remove();
  const frame = document.createElement("iframe");
  frame.className = "jt-print-frame";
  frame.setAttribute("aria-hidden", "true");
  frame.tabIndex = -1;
  document.body.append(frame);
  const win = frame.contentWindow;
  if (!win) {
    frame.remove();
    return;
  }
  whenLoaded(build(win, topic, post, siteTitle)).then(() => {
    win.addEventListener("afterprint", () => frame.remove(), { once: true });
    win.focus();
    win.print();
  });
}

function build(
  win: Window,
  topic: PrintTopic,
  post: PrintPost,
  siteTitle: string
) {
  const doc = win.document;
  // a fresh frame's about:blank is in quirks mode: a doctype first
  doc.open();
  doc.write('<!doctype html><meta charset="utf-8">');
  doc.close();

  const html = doc.documentElement;
  const page = document.documentElement;
  html.lang = page.lang;
  html.classList.add("jt-print-doc");
  if (page.classList.contains("rtl")) {
    html.classList.add("rtl");
    html.dir = "rtl";
  }
  doc.title = `${topic.title} - ${siteTitle}`;

  const base = doc.createElement("base");
  base.href = getAbsoluteURL("/");
  doc.head.append(base);
  for (const link of document.querySelectorAll('link[rel="stylesheet"]')) {
    doc.head.append(doc.importNode(link, true));
  }

  const main = doc.createElement("main");
  main.className = "jt-print";

  const title = doc.createElement("h1");
  title.className = "jt-print__title";
  title.textContent = topic.title;

  const date = new Date(post.created_at).toLocaleDateString(
    page.lang || undefined,
    { dateStyle: "long" }
  );
  const byline = doc.createElement("p");
  byline.className = "jt-print__meta";
  byline.textContent = `${post.name || post.username} · ${date}`;

  const cooked = doc.createElement("div");
  cooked.className = "cooked";
  // core's sanitised post HTML, as the topic page shows it
  cooked.innerHTML = post.cooked;
  for (const img of cooked.querySelectorAll("img")) {
    img.loading = "eager";
  }

  const source = doc.createElement("p");
  source.className = "jt-print__source";
  source.textContent = getAbsoluteURL(topic.url);

  main.append(title, byline, cooked, source);
  doc.body.append(main);
  return doc;
}

function whenLoaded(doc: Document) {
  const loads = [
    ...doc.querySelectorAll<HTMLLinkElement | HTMLImageElement>(
      'link[rel="stylesheet"], img'
    ),
  ].map(
    (el) =>
      new Promise<void>((resolve) => {
        if (el instanceof HTMLImageElement && el.complete) {
          resolve();
          return;
        }
        el.addEventListener("load", () => resolve(), { once: true });
        el.addEventListener("error", () => resolve(), { once: true });
      })
  );
  return Promise.race([
    Promise.all(loads),
    new Promise((resolve) => setTimeout(resolve, LOAD_TIMEOUT)),
  ]);
}
