// Showing spoilers and [details] from the post menu (D-pad users can't
// focus them inside a post).
import assert from "node:assert/strict";
import { before, test } from "node:test";

type Hidden = typeof import("../src/ui/hidden-text.ts");
let hidden: Hidden;

before(async () => {
  await import("./stub-dom.ts");
  hidden = await import("../src/ui/hidden-text.ts");
});

function spoiler(revealed = false): Element {
  const set: Record<string, boolean> = { revealed };
  return {
    classList: {
      contains: (c: string) => !!set[c],
      add: (c: string) => (set[c] = true),
      remove: (c: string) => (set[c] = false),
    },
  } as unknown as Element;
}

function details(open = false): Element {
  const attrs: Record<string, string> = open ? { open: "" } : {};
  return {
    hasAttribute: (a: string) => a in attrs,
    setAttribute: (a: string, v: string) => (attrs[a] = v),
    removeAttribute: (a: string) => delete attrs[a],
  } as unknown as Element;
}

test("a post with no spoilers or details offers nothing", () => {
  assert.equal(hidden.hiddenState({ spoilers: [], details: [] }), null);
});

test("closed details or a covered spoiler counts as hidden", () => {
  assert.equal(
    hidden.hiddenState({ spoilers: [], details: [details()] }),
    "hidden"
  );
  assert.equal(
    hidden.hiddenState({ spoilers: [spoiler(true), spoiler()], details: [] }),
    "hidden"
  );
});

test("show opens everything, hide closes it again", () => {
  const p = {
    spoilers: [spoiler(), spoiler(true)],
    details: [details(), details(true)],
  };
  hidden.showHidden(p, true);
  assert.equal(hidden.hiddenState(p), "shown");
  hidden.showHidden(p, false);
  assert.equal(hidden.hiddenState(p), "hidden");
  assert.equal(p.details[1].hasAttribute("open"), false);
  assert.equal(p.spoilers[1].classList.contains("revealed"), false);
});
