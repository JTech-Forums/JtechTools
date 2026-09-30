import assert from "node:assert/strict";
import { test } from "node:test";
import { escapeHtml, html, join, raw, safeUrl } from "../src/html.ts";

test("escapes every interpolated value", () => {
  const evil = `<img src=x onerror="alert(1)">'&\``;
  assert.equal(
    html`<p>${evil}</p>`.value,
    "<p>&lt;img src=x onerror=&quot;alert(1)&quot;&gt;&#39;&amp;&#96;</p>"
  );
});

test("keeps SafeHtml and arrays of SafeHtml as they are", () => {
  const items = ["a", "<b>"].map((x) => html`<li>${x}</li>`);
  assert.equal(
    html`<ul>
      ${items}
    </ul>`.value.replace(/>\s+</g, "><"),
    "<ul><li>a</li><li>&lt;b&gt;</li></ul>"
  );
  assert.equal(html`${raw("<em>ok</em>")}`.value, "<em>ok</em>");
});

test("renders nothing for null, undefined and false", () => {
  assert.equal(html`[${null}${undefined}${false}]`.value, "[]");
  assert.equal(html`${0}`.value, "0");
});

test("join escapes strings and keeps SafeHtml", () => {
  assert.equal(join(["<a>", html`<b></b>`], ", ").value, "&lt;a&gt;, <b></b>");
});

test("safeUrl only lets through harmless schemes", () => {
  assert.equal(safeUrl("javascript:alert(1)"), "#");
  assert.equal(safeUrl(" JaVaScRiPt:alert(1)"), "#");
  assert.equal(safeUrl("data:text/html,<script>"), "#");
  assert.equal(safeUrl("vbscript:x"), "#");
  assert.equal(
    safeUrl("https://example.com/a?b=1"),
    "https://example.com/a?b=1"
  );
  assert.equal(safeUrl("tel:+17185550100"), "tel:+17185550100");
  assert.equal(safeUrl("mailto:a@b.co"), "mailto:a@b.co");
  assert.equal(safeUrl("/t/topic/1"), "/t/topic/1");
  assert.equal(safeUrl(""), "#");
});

test("escapeHtml handles non-strings", () => {
  assert.equal(escapeHtml(5), "5");
  assert.equal(escapeHtml(undefined), "");
});
