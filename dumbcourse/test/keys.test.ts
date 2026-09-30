import assert from "node:assert/strict";
import { test } from "node:test";
import { isDeferred, keyOf, keySignature, setCustomKeys } from "../src/keys.ts";

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

test("engines that only report the physical key code", () => {
  assert.equal(keyOf(ev({ key: "Unidentified", code: "F1" })), "softleft");
  assert.equal(keyOf(ev({ key: "Unidentified", code: "Digit4" })), "4");
  assert.equal(keyOf(ev({ key: "Unidentified", code: "Numpad9" })), "9");
  assert.equal(keyOf(ev({ key: "Unidentified", code: "NumpadMultiply" })), "*");
});

test("Gecko keypad keyCodes and other soft-key names", () => {
  assert.equal(keyOf(ev({ keyCode: 170 })), "*");
  assert.equal(keyOf(ev({ keyCode: 163 })), "#");
  assert.equal(keyOf(ev({ key: "Soft1" })), "softleft");
  assert.equal(keyOf(ev({ key: "Soft2" })), "softright");
});

test("key signatures and anonymous keydowns", () => {
  assert.equal(keySignature(ev({ key: "SoftLeft" })), "key:SoftLeft");
  assert.equal(
    keySignature(ev({ key: "Unidentified", code: "F9" })),
    "code:F9"
  );
  assert.equal(keySignature(ev({ key: "Unidentified", keyCode: 1 })), "kc:1");
  assert.equal(keySignature(ev({ key: "Unidentified", keyCode: 229 })), null);
  assert.equal(isDeferred(ev({ key: "Unidentified", keyCode: 229 })), true);
  assert.equal(isDeferred(ev({ key: "Unidentified", keyCode: 0 })), true);
  assert.equal(isDeferred(ev({ key: "ArrowUp", keyCode: 38 })), false);
});

test("taught keys win, except typing a character", () => {
  setCustomKeys({ "kc:1": "softleft", "key:*": "softright" });
  try {
    assert.equal(keyOf(ev({ key: "Unidentified", keyCode: 1 })), "softleft");
    assert.equal(keyOf(ev({ key: "*" })), "softright");
    assert.equal(keyOf(ev({ key: "*" }), true), "*");
    assert.equal(
      keyOf(ev({ key: "Unidentified", keyCode: 1 }), true),
      "softleft"
    );
  } finally {
    setCustomKeys(null);
  }
  assert.equal(keyOf(ev({ key: "Unidentified", keyCode: 1 })), null);
});
