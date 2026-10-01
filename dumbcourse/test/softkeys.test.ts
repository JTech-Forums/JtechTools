// When "Soft-key bar: Keypad phones" turns the bar on (issue #86: it showed
// on ordinary touch phones, which are as narrow as feature phones).
import assert from "node:assert/strict";
import { before, beforeEach, test } from "node:test";

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

beforeEach(() => {
  prefs.setPref("softkeys", "auto");
  prefs.setPref("keypad", false);
});

test("keypad-only phones get the bar straight away", () => {
  device(240, false);
  assert.equal(prefs.softkeysVisible(), true);
  device(480, false);
  assert.equal(prefs.softkeysVisible(), true);
});

test("touch phones don't, whatever their width", () => {
  device(240, true);
  assert.equal(prefs.softkeysVisible(), false);
  device(412, true);
  assert.equal(prefs.softkeysVisible(), false);
});

test("a touch phone gets it once it presses a D-pad or soft key", () => {
  device(360, true);
  prefs.noteKey("enter", false);
  prefs.noteKey("5", false);
  assert.equal(prefs.softkeysVisible(), false);
  prefs.noteKey("down", true);
  assert.equal(prefs.softkeysVisible(), false, "typing in a field");
  prefs.noteKey("down", false);
  assert.equal(prefs.softkeysVisible(), true);
});

test("wide screens never do on auto", () => {
  device(1280, false);
  prefs.noteKey("softleft", false);
  assert.equal(prefs.softkeysVisible(), false);
});

test("Always and Never override it", () => {
  device(412, true);
  prefs.setPref("softkeys", "on");
  assert.equal(prefs.softkeysVisible(), true);
  device(240, false);
  prefs.setPref("softkeys", "off");
  assert.equal(prefs.softkeysVisible(), false);
});
