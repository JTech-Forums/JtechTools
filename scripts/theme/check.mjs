#!/usr/bin/env node
// Pre-update gate for the JTech theme. Run against a LOCAL forum after moving
// it to a new Discourse version, before updating production:
//
//   node scripts/theme/check.mjs                (anonymous only)
//   JT_PW=… node scripts/theme/check.mjs        (also logs in, as JT_USER or devadmin)
//
//   JTECH_THEME_URL   forum to check (default http://localhost:3000; must be localhost)
//   PLAYWRIGHT_PATH / CHROME   where Playwright and its Chromium live
//
// Fails (exit 1) when:
//   - a core module the theme imports no longer exists (the whole theme's JS
//     would fail to load on that version)
//   - the theme fails to load, throws, or logs a deprecation attributed to it
//   - a JTech surface that should render doesn't
// Deprecations from *other* themes/components are listed as warnings.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { createRequire } from "node:module";

const BASE = process.env.JTECH_THEME_URL || "http://localhost:3000";
if (!/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(BASE)) {
  console.error(`refusing: ${BASE} is not a local forum`);
  process.exit(1);
}
const THEME_DIR = new URL("../../themes/jtech/", import.meta.url).pathname;
const PW_PATH =
  process.env.PLAYWRIGHT_PATH ||
  `${process.env.HOME}/.local/share/mise/installs/npm-playwright/latest/node_modules/playwright`;
const CHROME =
  process.env.CHROME ||
  `${process.env.HOME}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome`;

const { chromium } = createRequire(import.meta.url)(PW_PATH);

const failures = [];
const warnings = [];
const ok = [];

// 1. Core modules imported by the theme
function walk(dir) {
  return readdirSync(dir).flatMap((f) => {
    const p = join(dir, f);
    return statSync(p).isDirectory() ? walk(p) : [p];
  });
}
const sources = walk(join(THEME_DIR, "javascripts")).filter((f) =>
  /\.(gjs|js)$/.test(f)
);
const imports = new Map(); // module -> files
for (const file of sources) {
  const text = readFileSync(file, "utf8");
  for (const [, mod] of text.matchAll(/^import[^"']*["']([^"']+)["']/gm)) {
    if (mod.startsWith(".") || mod.startsWith("virtual:")) {
      continue;
    }
    if (!imports.has(mod)) {
      imports.set(mod, []);
    }
    imports.get(mod).push(file.replace(THEME_DIR, ""));
  }
}

const browser = await chromium.launch({ executablePath: CHROME });

async function context(auth) {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  if (auth) {
    const csrf = (
      await (
        await ctx.request.get(`${BASE}/session/csrf`, {
          headers: { "X-Requested-With": "XMLHttpRequest" },
        })
      ).json()
    ).csrf;
    const r = await ctx.request.post(`${BASE}/session`, {
      headers: { "X-CSRF-Token": csrf, "X-Requested-With": "XMLHttpRequest" },
      form: { login: process.env.JT_USER || "devadmin", password: process.env.JT_PW },
    });
    if (!(await r.json()).user) {
      throw new Error("login failed");
    }
  }
  return ctx;
}

const anon = await context(false);
const page = await anon.newPage();
await page.goto(`${BASE}/latest`, { waitUntil: "load" });
await page.waitForTimeout(2500);
const missing = await page.evaluate(
  (mods) => mods.filter((m) => !window.require.has(m)),
  [...imports.keys()]
);
for (const m of missing) {
  failures.push(`missing core module ${m}  (used by ${imports.get(m).join(", ")})`);
}
ok.push(`${imports.size - missing.length}/${imports.size} core imports resolve`);
await anon.close();

// 2. Console sweep + 3. smoke, per page
const topic = await (await fetch(`${BASE}/latest.json`)).json();
const topicId = topic.topic_list.topics.find((t) => t.posts_count > 3)?.id;

const PAGES = [
  ["/", [".jt-hero"]],
  ["/latest", [".jt-card"]],
  ["/categories", [".jt-footer"]],
  [`/t/${topicId}`, [".topic-post", ".jt-progress"]],
  ["/leaderboard", [".leaderboard", ".jt-footer"]],
];

for (const auth of process.env.JT_PW ? [false, true] : [false]) {
  const who = auth ? "admin" : "anon";
  const ctx = await context(auth);
  const p = await ctx.newPage();
  const lines = [];
  p.on("console", (m) => lines.push(`${m.type()}: ${m.text()}`));
  p.on("pageerror", (e) => lines.push(`pageerror: ${e.message}`));

  for (const [path, selectors] of PAGES) {
    lines.length = 0;
    await p.goto(`${BASE}${path}`, { waitUntil: "load" });
    await p.waitForTimeout(2500);

    for (const sel of selectors) {
      if (!(await p.locator(sel).count())) {
        failures.push(`${who} ${path}: ${sel} did not render`);
      }
    }
    for (const l of lines) {
      const ours = /\[THEME 119\b|'JTech'|theme 119/i.test(l);
      if (ours && /DEPRECATION/i.test(l)) {
        failures.push(`${who} ${path}: deprecation in JTech: ${l.slice(0, 220)}`);
      } else if (ours && /^(error|pageerror)/.test(l)) {
        failures.push(`${who} ${path}: ${l.slice(0, 220)}`);
      } else if (/DEPRECATION/i.test(l)) {
        const w = l.replace(/\s+at .*/s, "").slice(0, 200);
        if (!warnings.includes(w)) {
          warnings.push(w);
        }
      }
    }
  }
  ok.push(`${who}: ${PAGES.length} pages swept`);
  await ctx.close();
}

await browser.close();

for (const o of ok) {
  console.log(`ok    ${o}`);
}
for (const w of warnings) {
  console.log(`warn  ${w}`);
}
for (const f of failures) {
  console.log(`FAIL  ${f}`);
}
console.log(failures.length ? `\n${failures.length} failure(s)` : "\nall checks passed");
process.exit(failures.length ? 1 : 0);
