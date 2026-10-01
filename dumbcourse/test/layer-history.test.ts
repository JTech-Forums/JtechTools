// One history entry per open layer, kept right when layers open and close in
// the same click (ui/layer-history.ts).
import assert from "node:assert/strict";
import { test } from "node:test";

import { createLayerHistory } from "../src/ui/layer-history.ts";

// A fake browser history: a list of entries and a pointer, where go() is
// asynchronous like the real one (it lands when flush() runs).
function setup() {
  let depth = 0;
  const entries = ["screen"];
  let index = 0;
  const log: string[] = [];
  let tasks: Array<() => void> = [];
  let canPush = true;
  const h = createLayerHistory({
    depth: () => depth,
    push: () => {
      if (!canPush) return false;
      entries.length = index + 1;
      entries.push("layer");
      index++;
      log.push("push");
      return true;
    },
    go: (delta) => {
      log.push("go(" + delta + ")");
      tasks.push(() => {
        index += delta;
        if (!h.popped()) log.push("pop not ours");
      });
    },
    defer: (fn) => {
      tasks.push(fn);
    },
  });
  const flush = () => {
    while (tasks.length) {
      const run = tasks;
      tasks = [];
      run.forEach((fn) => fn());
    }
  };
  return {
    h,
    log,
    flush,
    setDepth: (n: number) => {
      depth = n;
      h.changed();
    },
    current: () => entries[index],
    index: () => index,
    // The user presses Back: the browser moves first, then fires popstate.
    back: () => {
      index--;
      return h.popped();
    },
    noPush: () => {
      canPush = false;
    },
  };
}

test("opening a layer adds one entry once the click is over", () => {
  const t = setup();
  t.setDepth(1);
  assert.deepEqual(t.log, []);
  t.flush();
  assert.deepEqual(t.log, ["push"]);
  assert.equal(t.current(), "layer");
});

test("a menu item that closes its sheet and opens the composer keeps one entry", () => {
  const t = setup();
  t.setDepth(1); // topic menu
  t.flush();
  t.setDepth(0); // the item closes the menu…
  t.setDepth(1); // …and opens the composer, in the same click
  t.flush();
  // Before the fix the menu's back() landed after the composer's push and
  // took the composer's entry with it.
  assert.deepEqual(t.log, ["push"]);
  assert.equal(t.index(), 1);
  assert.equal(t.current(), "layer");
});

test("a confirm dialog closing with its composer goes back to the screen, not past it", () => {
  const t = setup();
  t.setDepth(1); // composer
  t.flush();
  t.setDepth(2); // "Throw away this draft?"
  t.flush();
  t.setDepth(1); // dialog closes…
  t.setDepth(0); // …and so does the composer
  t.flush();
  assert.deepEqual(t.log, ["push", "push", "go(-2)"]);
  assert.equal(t.index(), 0);
  assert.equal(t.current(), "screen");
});

test("Back over a layer is the user's, not ours, and needs no history change", () => {
  const t = setup();
  t.setDepth(1);
  t.flush();
  assert.equal(t.back(), false);
  t.setDepth(0); // the router hook removes the layer
  t.flush();
  assert.deepEqual(t.log, ["push"]);
  assert.equal(t.current(), "screen");
});

test("a layer that stays open after Back (it asks first) gets its entry back", () => {
  const t = setup();
  t.setDepth(1); // composer with writing in it
  t.flush();
  assert.equal(t.back(), false);
  t.setDepth(2); // it stays open and shows "Close?"
  t.flush();
  assert.deepEqual(t.log, ["push", "push", "push"]);
  assert.equal(t.index(), 2);
  t.setDepth(1); // Keep writing
  t.flush();
  assert.equal(t.index(), 1);
  assert.equal(t.current(), "layer");
});

test("leaving the screen right after closing a layer replaces that layer's entry", () => {
  const t = setup();
  t.setDepth(1);
  t.flush();
  t.setDepth(0); // a sheet item closes the sheet and navigates
  assert.equal(t.h.reset(), 1);
  t.flush();
  assert.deepEqual(t.log, ["push"], "the queued back() is dropped");
});

test("a replacing move from a layer goes back to the screen entry first", () => {
  const t = setup();
  t.setDepth(1); // "Jump to post" prompt
  t.flush();
  t.setDepth(0); // Go closes it…
  const n = t.h.reset(); // …and jumps, replacing the topic's entry
  let ranOn = "";
  t.h.popThen(n, () => {
    ranOn = t.current();
  });
  t.flush();
  assert.equal(ranOn, "screen", "the jump replaces the topic, not the prompt");
  assert.deepEqual(t.log, ["push", "go(-1)"]);
});

test("engines without pushState never go back for a layer", () => {
  const t = setup();
  t.noPush();
  t.setDepth(1);
  t.flush();
  t.setDepth(0);
  t.flush();
  assert.deepEqual(t.log, []);
  assert.equal(t.h.reset(), 0);
});
