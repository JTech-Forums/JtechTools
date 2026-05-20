import { module, test } from "qunit";
import { CREATE_TOPIC } from "discourse/models/composer";
import {
  firstPostChecklistFor,
  refreshOwedChecklist,
} from "discourse/plugins/JtechTools/discourse/lib/first-post-checklist";
import { REPLY_ACTION } from "discourse/plugins/JtechTools/discourse/lib/precheck-prompt";

// Pure-function unit tests for first-post checklist gate resolution. The
// server decides eligibility (trust level / version); the frontend only
// gates on the composer action and a non-empty checklist.

const CHECKLIST = {
  kind: "global",
  version: 2,
  items: [{ label: "Read the rules", url: "" }],
};

const TARGETED_CHECKLIST = {
  kind: "targeted",
  id: "abc123",
  version: 1,
  items: [{ label: "Read the app rules", url: "" }],
};

module("Unit | discourse-mod | first-post-checklist", function () {
  test("returns the checklist for a new topic", function (assert) {
    assert.strictEqual(
      firstPostChecklistFor(
        { action: CREATE_TOPIC },
        { mod_first_post_checklist: CHECKLIST }
      ),
      CHECKLIST
    );
  });

  test("returns the checklist for a reply", function (assert) {
    assert.strictEqual(
      firstPostChecklistFor(
        { action: REPLY_ACTION },
        { mod_first_post_checklist: CHECKLIST }
      ),
      CHECKLIST
    );
  });

  ["edit", "privateMessage", "editSharedDraft", "", null, undefined].forEach(
    (action) => {
      test(`action=${JSON.stringify(action)} is never gated`, function (assert) {
        assert.strictEqual(
          firstPostChecklistFor(
            { action },
            { mod_first_post_checklist: CHECKLIST }
          ),
          null
        );
      });
    }
  );

  test("returns null when the user has no checklist", function (assert) {
    assert.strictEqual(
      firstPostChecklistFor({ action: CREATE_TOPIC }, {}),
      null
    );
  });

  test("returns null when the checklist is null", function (assert) {
    assert.strictEqual(
      firstPostChecklistFor(
        { action: CREATE_TOPIC },
        { mod_first_post_checklist: null }
      ),
      null
    );
  });

  test("returns null when the checklist has no items", function (assert) {
    assert.strictEqual(
      firstPostChecklistFor(
        { action: CREATE_TOPIC },
        { mod_first_post_checklist: { version: 1, items: [] } }
      ),
      null
    );
  });

  test("statement-mode checklist with a non-blank statement is gated", function (assert) {
    const checklist = {
      kind: "topic",
      version: 1,
      mode: "statement",
      statement: "Please confirm you have read the rules.",
      items: [],
    };
    assert.strictEqual(
      firstPostChecklistFor(
        { action: REPLY_ACTION },
        { mod_first_post_checklist: checklist }
      ),
      checklist
    );
  });

  test("statement-mode checklist with a blank statement is not gated", function (assert) {
    const checklist = {
      kind: "topic",
      version: 1,
      mode: "statement",
      statement: "   ",
      items: [],
    };
    assert.strictEqual(
      firstPostChecklistFor(
        { action: REPLY_ACTION },
        { mod_first_post_checklist: checklist }
      ),
      null
    );
  });

  test("returns null with no composer", function (assert) {
    assert.strictEqual(
      firstPostChecklistFor(null, { mod_first_post_checklist: CHECKLIST }),
      null
    );
  });

  test("returns null with no current user", function (assert) {
    assert.strictEqual(
      firstPostChecklistFor({ action: CREATE_TOPIC }, null),
      null
    );
  });

  test("carries a targeted checklist through unchanged", function (assert) {
    const result = firstPostChecklistFor(
      { action: CREATE_TOPIC },
      { mod_first_post_checklist: TARGETED_CHECKLIST }
    );
    assert.strictEqual(result, TARGETED_CHECKLIST);
    assert.strictEqual(result.kind, "targeted");
    assert.strictEqual(result.id, "abc123");
  });

  test("passes an updated_at-carrying checklist through unchanged", function (assert) {
    const checklist = { ...CHECKLIST, updated_at: "2026-01-02T03:04:05Z" };
    const result = firstPostChecklistFor(
      { action: REPLY_ACTION },
      { mod_first_post_checklist: checklist }
    );
    assert.strictEqual(result, checklist);
    assert.strictEqual(result.updated_at, "2026-01-02T03:04:05Z");
  });

  test("refreshOwedChecklist resolves without a current user", async function (assert) {
    // No user means no session to refresh; it must not throw or fetch.
    await refreshOwedChecklist(null);
    assert.true(true, "resolved without error");
  });
});
