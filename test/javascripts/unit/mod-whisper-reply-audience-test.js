import { module, test } from "qunit";
import { computeReplyAudience } from "discourse/plugins/discourse-mod/discourse/lib/mod-whisper-reply-audience";

// Pure-function unit tests for the whisper reply-audience helper. End-to-end
// behaviour is in spec/system.

module("Unit | discourse-mod | mod-whisper-reply-audience", function () {
  test("returns [] when post is missing", function (assert) {
    assert.deepEqual(computeReplyAudience(null, 1), []);
    assert.deepEqual(computeReplyAudience(undefined, 1), []);
  });

  test("returns [] when currentUserId is missing", function (assert) {
    assert.deepEqual(computeReplyAudience({ user_id: 5 }, null), []);
    assert.deepEqual(computeReplyAudience({ user_id: 5 }, undefined), []);
  });

  test("includes the post author", function (assert) {
    const result = computeReplyAudience(
      { user_id: 5, username: "alice", avatar_template: "/a.png" },
      99
    );
    assert.deepEqual(result, [
      { id: 5, username: "alice", avatar_template: "/a.png" },
    ]);
  });

  test("excludes the current user when they are the author", function (assert) {
    const result = computeReplyAudience({ user_id: 5, username: "alice" }, 5);
    assert.deepEqual(result, []);
  });

  test("includes the explicit targets", function (assert) {
    const result = computeReplyAudience(
      {
        user_id: 1,
        username: "author",
        mod_whisper_targets: [
          { id: 2, username: "bob", avatar_template: "/b.png" },
          { id: 3, username: "carol", avatar_template: "/c.png" },
        ],
      },
      99
    );
    assert.deepEqual(result.map((u) => u.id).sort(), [1, 2, 3]);
  });

  test("excludes the current user from the targets", function (assert) {
    const result = computeReplyAudience(
      {
        user_id: 1,
        username: "author",
        mod_whisper_targets: [
          { id: 2, username: "bob" },
          { id: 7, username: "me" },
        ],
      },
      7
    );
    assert.deepEqual(result.map((u) => u.id).sort(), [1, 2]);
  });

  test("deduplicates author appearing as a target", function (assert) {
    const result = computeReplyAudience(
      {
        user_id: 1,
        username: "author",
        mod_whisper_targets: [
          { id: 1, username: "author" },
          { id: 2, username: "bob" },
        ],
      },
      99
    );
    assert.deepEqual(result.map((u) => u.id).sort(), [1, 2]);
  });

  test("tolerates a non-array mod_whisper_targets", function (assert) {
    const result = computeReplyAudience(
      { user_id: 1, username: "author", mod_whisper_targets: "nope" },
      99
    );
    assert.deepEqual(
      result.map((u) => u.id),
      [1]
    );
  });

  test("ignores malformed target entries", function (assert) {
    const result = computeReplyAudience(
      {
        user_id: 1,
        username: "author",
        mod_whisper_targets: [null, undefined, 42, { id: 2, username: "b" }],
      },
      99
    );
    assert.deepEqual(result.map((u) => u.id).sort(), [1, 2]);
  });
});
