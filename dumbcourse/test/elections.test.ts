import assert from "node:assert/strict";
import { test } from "node:test";
import { moveBy, placeAt, removeFrom, sameRanking } from "../src/ballot.ts";

test("pressing a number puts the candidate in that place", () => {
  assert.deepEqual(placeAt([], 7, 1), [7]);
  assert.deepEqual(placeAt([1, 2, 3], 9, 2), [1, 9, 2, 3]);
  // Already ranked: it moves rather than appearing twice.
  assert.deepEqual(placeAt([1, 2, 3], 3, 1), [3, 1, 2]);
  assert.deepEqual(placeAt([1, 2, 3], 1, 3), [2, 3, 1]);
});

test("a place past the end puts the candidate last", () => {
  assert.deepEqual(placeAt([1, 2], 5, 9), [1, 2, 5]);
  assert.deepEqual(placeAt([1, 2, 3], 1, 9), [2, 3, 1]);
});

test("moving up and down stops at the ends", () => {
  assert.deepEqual(moveBy([1, 2, 3], 2, -1), [2, 1, 3]);
  assert.deepEqual(moveBy([1, 2, 3], 2, 1), [1, 3, 2]);
  assert.deepEqual(moveBy([1, 2, 3], 1, -1), [1, 2, 3]);
  assert.deepEqual(moveBy([1, 2, 3], 3, 1), [1, 2, 3]);
  assert.deepEqual(moveBy([1, 2, 3], 8, 1), [1, 2, 3]);
});

test("0 takes a candidate off", () => {
  assert.deepEqual(removeFrom([1, 2, 3], 2), [1, 3]);
  assert.deepEqual(removeFrom([1, 2, 3], 8), [1, 2, 3]);
});

test("a changed order counts as a change", () => {
  assert.equal(sameRanking([1, 2], [1, 2]), true);
  assert.equal(sameRanking([1, 2], [2, 1]), false);
  assert.equal(sameRanking([1], [1, 2]), false);
});
