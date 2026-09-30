import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import * as espree from "espree";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");

for (const file of ["public/dumbcourse.js", "public/dumbcourse-early.js"]) {
  test(`${file} is plain ECMAScript 5`, () => {
    const code = readFileSync(join(root, file), "utf8");
    assert.doesNotThrow(() =>
      espree.parse(code, { ecmaVersion: 5, sourceType: "script" })
    );
    assert.doesNotMatch(
      code,
      /__makeTemplateObject/,
      "tagged templates were compiled to plain calls"
    );
  });
}

test("the page template has every placeholder the server fills", () => {
  const page = readFileSync(join(root, "public/index.html"), "utf8");
  for (const p of [
    "{{TITLE}}",
    "{{BASE}}",
    "{{VERSION}}",
    "{{BOOT}}",
    "{{EARLY}}",
    "{{DEFAULT_THEME}}",
  ])
    assert.ok(page.includes(p), p);
  assert.doesNotMatch(
    page,
    /<script>(?!\{\{EARLY\}\})/,
    "no inline script besides the hashed early one"
  );
});
