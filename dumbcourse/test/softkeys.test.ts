// When "Soft-key bar: Keypad phones" turns the bar on (issue #86: it showed
// on ordinary phones, which are as narrow as keypad phones in CSS pixels).
import assert from "node:assert/strict";
import { before, beforeEach, test } from "node:test";

type Prefs = typeof import("../src/prefs.ts");

let prefs: Prefs;
const g = globalThis as unknown as Record<string, unknown>;

// Viewport width in CSS px, screen in device px.
function device(width: number, screenW: number, screenH: number): void {
  g.innerWidth = width;
  g.screen = { width: screenW, height: screenH };
}

before(async () => {
  await import("./stub-dom.ts");
  prefs = await import("../src/prefs.ts");
});

beforeEach(() => {
  prefs.setPref("softkeys", "auto");
  prefs.setPref("keypad", false);
});

test("keypad phones get the bar", () => {
  device(240, 240, 320);
  assert.equal(prefs.softkeysVisible(), true, "KaiOS 240x320");
  device(320, 480, 640);
  assert.equal(prefs.softkeysVisible(), true, "flip phone 480x640");
  device(320, 640, 480);
  assert.equal(prefs.softkeysVisible(), true, "landscape");
});

test("ordinary phones don't, touch or not", () => {
  device(411, 1440, 3168);
  assert.equal(prefs.softkeysVisible(), false, "issue #86");
  device(360, 1080, 2400);
  assert.equal(prefs.softkeysVisible(), false);
  device(320, 480, 800);
  assert.equal(prefs.softkeysVisible(), false, "480x800");
});

test("a tall phone gets it once it presses a D-pad or soft key", () => {
  device(360, 720, 1600);
  prefs.noteKey("enter", false);
  prefs.noteKey("5", false);
  assert.equal(prefs.softkeysVisible(), false);
  prefs.noteKey("down", true);
  assert.equal(prefs.softkeysVisible(), false, "typing in a field");
  prefs.noteKey("down", false);
  assert.equal(prefs.softkeysVisible(), true);
});

test("unknown screen size falls back to width", () => {
  device(240, 0, 0);
  assert.equal(prefs.softkeysVisible(), true);
});

test("wide windows never do on auto", () => {
  device(1280, 1920, 1080);
  prefs.noteKey("softleft", false);
  assert.equal(prefs.softkeysVisible(), false);
  device(1280, 1600, 1200);
  assert.equal(prefs.softkeysVisible(), false, "4:3 monitor");
});

test("Always and Never override it", () => {
  device(411, 1440, 3168);
  prefs.setPref("softkeys", "on");
  assert.equal(prefs.softkeysVisible(), true);
  device(240, 240, 320);
  prefs.setPref("softkeys", "off");
  assert.equal(prefs.softkeysVisible(), false);
});
