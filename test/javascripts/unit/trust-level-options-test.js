import { module, test } from "qunit";
import { trustLevelOptions } from "discourse/plugins/discourse-mod/discourse/lib/trust-level-options";

// Pure-function unit tests for the trust-level audience dropdown options.
// The prompt caps include "Everyone" (4) and "Up to regulars" (3); the
// first-post checklist omits them since it only gates TL0-2.

module("Unit | discourse-mod | trust-level-options", function () {
  test("defaults to including all five audience choices", function (assert) {
    const ids = trustLevelOptions().map((o) => o.id);
    assert.deepEqual(ids, ["4", "0", "1", "2", "3"]);
  });

  test("includeAll=true keeps Everyone and Up-to-regulars", function (assert) {
    const ids = trustLevelOptions(true).map((o) => o.id);
    assert.deepEqual(ids, ["4", "0", "1", "2", "3"]);
  });

  test("includeAll=false drops the 3 and 4 choices", function (assert) {
    const ids = trustLevelOptions(false).map((o) => o.id);
    assert.deepEqual(ids, ["0", "1", "2"]);
  });

  test("every option has a string id and a name", function (assert) {
    trustLevelOptions().forEach((o) => {
      assert.strictEqual(typeof o.id, "string", `id ${o.id} is a string`);
      assert.ok(
        o.name !== undefined && o.name !== null,
        `option ${o.id} has a name`
      );
    });
  });

  test("ids are unique", function (assert) {
    const ids = trustLevelOptions().map((o) => o.id);
    assert.strictEqual(new Set(ids).size, ids.length);
  });

  test("checklist subset is contained in the full set", function (assert) {
    const full = new Set(trustLevelOptions(true).map((o) => o.id));
    trustLevelOptions(false).forEach((o) => {
      assert.true(full.has(o.id), `id ${o.id} is also in the full set`);
    });
  });

  test("the TL0-TL2 options keep their order in both variants", function (assert) {
    const full = trustLevelOptions(true).map((o) => o.id);
    const subset = trustLevelOptions(false).map((o) => o.id);
    assert.deepEqual(subset, ["0", "1", "2"]);
    // 0,1,2 appear in the same relative order inside the full list.
    assert.deepEqual(
      full.filter((id) => subset.includes(id)),
      subset
    );
  });

  test("returns a fresh array on each call", function (assert) {
    const a = trustLevelOptions();
    const b = trustLevelOptions();
    assert.notStrictEqual(a, b);
    a.push({ id: "99", name: "x" });
    assert.strictEqual(trustLevelOptions().length, 5);
  });
});
