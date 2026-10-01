// When "Soft-key bar: Small screens" turns the bar on (issue #86: it showed
// on ordinary touch phones, which are all under 480 px wide).
import assert from "node:assert/strict";
import { before, test } from "node:test";

type Prefs = typeof import("../src/prefs.ts");

let prefs: Prefs;
const g = globalThis as unknown as Record<string, unknown>;

function device(width: number, touch: boolean): void {
  g.innerWidth = width;
  if (touch) g.ontouchstart = null;
  else delete g.ontouchstart;
}

before(async () => {
  await import("./stub-dom.ts");
  Object.defineProperty(globalThis, "navigator", {
    value: { userAgent: "test", maxTouchPoints: 0 },
    configurable: true,
  });
  prefs = await import("../src/prefs.ts");
});

test("keypad phones get the bar", () => {
  device(240, false);
  assert.equal(prefs.softkeysVisible(), true);
  device(320, false);
  assert.equal(prefs.softkeysVisible(), true);
});

test("small touch-and-keypad phones still get it", () => {
  device(240, true);
  assert.equal(prefs.softkeysVisible(), true);
  device(320, true);
  assert.equal(prefs.softkeysVisible(), true);
});

test("ordinary touch phones do not", () => {
  device(360, true);
  assert.equal(prefs.softkeysVisible(), false);
  device(412, true);
  assert.equal(prefs.softkeysVisible(), false);
});

test("wide screens do not", () => {
  device(1280, false);
  assert.equal(prefs.softkeysVisible(), false);
});

test("Always and Never override it", () => {
  device(412, true);
  prefs.setPref("softkeys", "on");
  assert.equal(prefs.softkeysVisible(), true);
  device(240, false);
  prefs.setPref("softkeys", "off");
  assert.equal(prefs.softkeysVisible(), false);
  prefs.setPref("softkeys", "auto");
});
