import assert from "node:assert/strict";
import { test } from "node:test";
import {
  count,
  longDate,
  parseDate,
  plural,
  timeAgo,
  truncate,
} from "../src/format.ts";

const NOW = Date.UTC(2026, 8, 30, 12, 0, 0);

test("timeAgo is short enough for a tiny screen", () => {
  assert.equal(timeAgo(new Date(NOW - 10 * 1000), NOW), "now");
  assert.equal(timeAgo(new Date(NOW - 5 * 60 * 1000), NOW), "5m");
  assert.equal(timeAgo(new Date(NOW - 3 * 3600 * 1000), NOW), "3h");
  assert.equal(timeAgo(new Date(NOW - 4 * 86400 * 1000), NOW), "4d");
  assert.match(
    timeAgo(new Date(NOW - 90 * 86400 * 1000), NOW),
    /^[A-Z][a-z]{2} \d+$/
  );
  assert.match(timeAgo(new Date(Date.UTC(2023, 0, 5)), NOW), /^Jan '23$/);
  assert.equal(timeAgo(null, NOW), "");
});

test("count abbreviates", () => {
  assert.equal(count(999), "999");
  assert.equal(count(1000), "1k");
  assert.equal(count(1250), "1.3k");
  assert.equal(count(15400), "15k");
  assert.equal(count(2500000), "2.5M");
  assert.equal(count(undefined), "0");
});

test("plural and truncate", () => {
  assert.equal(plural(1, "reply", "replies"), "1 reply");
  assert.equal(plural(3, "reply", "replies"), "3 replies");
  assert.equal(plural(2, "post"), "2 posts");
  assert.equal(truncate("short", 10), "short");
  assert.equal(truncate("one two three four five", 12), "one two…");
});

test("parseDate copes with ISO strings and junk", () => {
  assert.equal(
    parseDate("2026-09-30T12:00:00.123Z")?.getTime(),
    Date.UTC(2026, 8, 30, 12, 0, 0, 123)
  );
  assert.equal(parseDate("not a date"), null);
  assert.equal(longDate("2026-01-02T00:00:00Z").slice(0, 3), "Jan");
});
