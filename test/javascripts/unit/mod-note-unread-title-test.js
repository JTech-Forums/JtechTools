import { module, test } from "qunit";
import {
  applyUnreadPrefix,
  stripUnreadPrefix,
} from "discourse/plugins/discourse-mod/discourse/lib/mod-note-unread-title";

// Pure-function unit tests for the moderator-notes browser-tab title
// prefix. The header pip is a tracked-property render, so its reactivity
// is implicitly exercised by the Glimmer runtime; this suite locks in the
// title-prefix maths the initializer drives `document.title` with.

module("Unit | discourse-mod | mod-note-unread-title", function () {
  test("prefixes a non-zero count onto the bare title", function (assert) {
    assert.strictEqual(applyUnreadPrefix("My Forum", 3), "(3) My Forum");
  });

  test("returns the bare title for a zero count", function (assert) {
    assert.strictEqual(applyUnreadPrefix("My Forum", 0), "My Forum");
  });

  test("returns the bare title for a missing count", function (assert) {
    assert.strictEqual(applyUnreadPrefix("My Forum", null), "My Forum");
    assert.strictEqual(applyUnreadPrefix("My Forum", undefined), "My Forum");
  });

  test("is idempotent — repeated calls do not stack prefixes", function (assert) {
    const once = applyUnreadPrefix("My Forum", 2);
    const twice = applyUnreadPrefix(once, 2);
    assert.strictEqual(twice, "(2) My Forum");
  });

  test("re-prefixing with a new count replaces the old one", function (assert) {
    const before = applyUnreadPrefix("My Forum", 1);
    const after = applyUnreadPrefix(before, 5);
    assert.strictEqual(after, "(5) My Forum");
  });

  test("a zero count strips an existing prefix back off", function (assert) {
    const prefixed = applyUnreadPrefix("My Forum", 4);
    assert.strictEqual(applyUnreadPrefix(prefixed, 0), "My Forum");
  });

  test("stripUnreadPrefix removes the (N) shape but leaves other text alone", function (assert) {
    assert.strictEqual(stripUnreadPrefix("(7) My Forum"), "My Forum");
    assert.strictEqual(stripUnreadPrefix("My Forum"), "My Forum");
    assert.strictEqual(stripUnreadPrefix("(notes) My Forum"), "(notes) My Forum");
  });

  test("negative or non-numeric counts are treated as zero", function (assert) {
    assert.strictEqual(applyUnreadPrefix("My Forum", -1), "My Forum");
    assert.strictEqual(applyUnreadPrefix("My Forum", "abc"), "My Forum");
  });

  test("a numeric string count is honoured", function (assert) {
    assert.strictEqual(applyUnreadPrefix("My Forum", "2"), "(2) My Forum");
  });
});
