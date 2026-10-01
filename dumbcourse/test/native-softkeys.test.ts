// The native wrapper app's soft-key bridge (window.SoftkeyBridge).
import assert from "node:assert/strict";
import { afterEach, before, test } from "node:test";

type Native = typeof import("../src/native-softkeys.ts");

let native: Native;
const g = globalThis as unknown as Record<string, unknown>;

before(async () => {
  await import("./stub-dom.ts");
  native = await import("../src/native-softkeys.ts");
});

afterEach(() => {
  delete g.SoftkeyBridge;
});

test("a normal browser has no native soft keys", () => {
  assert.equal(native.nativeSoftkeys(), false);
  assert.equal(native.detectNativeSoftkeys(), false);
});

test("the app's bar is active: detection is offered and runs", () => {
  let calls = 0;
  g.SoftkeyBridge = { isActive: () => true, calibrate: () => calls++ };
  assert.equal(native.nativeSoftkeys(), true);
  assert.equal(native.detectNativeSoftkeys(), true);
  assert.equal(calls, 1);
});

test("the app's bar is off: the page keeps its own keys", () => {
  let calls = 0;
  g.SoftkeyBridge = { isActive: () => false, calibrate: () => calls++ };
  assert.equal(native.nativeSoftkeys(), false);
  assert.equal(native.detectNativeSoftkeys(), false);
  assert.equal(calls, 0);
});

test("an older app without calibrate, or a throwing bridge", () => {
  g.SoftkeyBridge = { isActive: () => true };
  assert.equal(native.nativeSoftkeys(), false);
  assert.equal(native.detectNativeSoftkeys(), false);
  g.SoftkeyBridge = {
    isActive: () => {
      throw new Error("gone");
    },
    calibrate: () => {},
  };
  assert.equal(native.nativeSoftkeys(), false);
  g.SoftkeyBridge = {
    isActive: () => true,
    calibrate: () => {
      throw new Error("gone");
    },
  };
  assert.equal(native.detectNativeSoftkeys(), false);
});
