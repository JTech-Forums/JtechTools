import assert from "node:assert/strict";
import { test } from "node:test";
import { keyOf } from "../src/keys.ts";

function ev(
  init: Partial<KeyboardEvent> & { key?: string; keyCode?: number }
): KeyboardEvent {
  return {
    ctrlKey: false,
    metaKey: false,
    altKey: false,
    shiftKey: false,
    which: 0,
    ...init,
  } as KeyboardEvent;
}

test("modern key names", () => {
  assert.equal(keyOf(ev({ key: "ArrowDown" })), "down");
  assert.equal(keyOf(ev({ key: "Enter" })), "enter");
  assert.equal(keyOf(ev({ key: "Backspace" })), "back");
  assert.equal(keyOf(ev({ key: "5" })), "5");
  assert.equal(keyOf(ev({ key: "*" })), "*");
  assert.equal(keyOf(ev({ key: "#" })), "#");
});

test("KaiOS soft keys and their desktop stand-ins", () => {
  assert.equal(keyOf(ev({ key: "SoftLeft" })), "softleft");
  assert.equal(keyOf(ev({ key: "SoftRight" })), "softright");
  assert.equal(keyOf(ev({ key: "F1" })), "softleft");
  assert.equal(keyOf(ev({ key: "F2" })), "softright");
});

test("old engines: legacy names and keyCode only", () => {
  assert.equal(keyOf(ev({ key: "Up" })), "up");
  assert.equal(keyOf(ev({ key: "Esc" })), "escape");
  assert.equal(keyOf(ev({ key: "Unidentified", keyCode: 39 })), "right");
  assert.equal(keyOf(ev({ keyCode: 13 })), "enter");
  assert.equal(keyOf(ev({ keyCode: 55 })), "7");
  assert.equal(keyOf(ev({ keyCode: 99 })), "3");
  assert.equal(keyOf(ev({ keyCode: 56, shiftKey: true })), "*");
  assert.equal(keyOf(ev({ keyCode: 51, shiftKey: true })), "#");
});

test("ignores shortcuts with modifiers and unknown keys", () => {
  assert.equal(keyOf(ev({ key: "5", ctrlKey: true })), null);
  assert.equal(keyOf(ev({ key: "a" })), null);
  assert.equal(keyOf(ev({ key: "Tab" })), null);
});
