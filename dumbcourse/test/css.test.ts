import assert from "node:assert/strict";
import { test } from "node:test";
import { resolveVars, transformCss } from "../css.ts";

const SOURCE = `
:root { --bg: #111; --fg: #eee; --line: var(--fg); }
html.light { --bg: #fff; --fg: #000; }
body { background: var(--bg); color: var(--fg); margin: 0; }
.row:focus { box-shadow: inset 4px 0 0 var(--line); }
@media (max-width: 300px) { .tb { border-color: var(--fg); } }
@keyframes spin { to { transform: rotate(360deg); } }
.same { color: var(--missing, red); }
`;

test("every var() gets a plain fallback in front of it", () => {
  const out = transformCss(SOURCE);
  assert.match(out, /background: #111;\s*background: var\(--bg\)/);
  assert.match(
    out,
    /box-shadow: inset 4px 0 0 #eee;\s*box-shadow: inset 4px 0 0 var\(--line\)/
  );
  assert.match(out, /color: red;\s*color: var\(--missing, red\)/);
});

test("the light theme is repeated for engines without custom properties", () => {
  const out = transformCss(SOURCE);
  const block = out.slice(out.indexOf("@supports not (--a: 0)"));
  assert.ok(block.length > 0, "has the @supports block");
  assert.match(block, /html\.light body\{background:#fff;color:#000\}/);
  assert.match(
    block,
    /html\.light \.row:focus\{box-shadow:inset 4px 0 0 #000\}/
  );
  assert.match(
    block,
    /@media \(max-width: 300px\)\{html\.light \.tb\{border-color:#000\}\}/
  );
  // Unchanged between themes: not repeated.
  assert.doesNotMatch(block, /\.same/);
});

test("resolveVars follows references and fallbacks", () => {
  const vars = { "--a": "var(--b)", "--b": "1px" };
  assert.equal(resolveVars("calc(var(--a) + 2px)", vars), "calc(1px + 2px)");
  assert.equal(resolveVars("var(--nope)", vars), null);
  assert.equal(resolveVars("var(--nope, 3px)", vars), "3px");
});
