import { module, test } from "qunit";
import { messageToHtml } from "discourse/plugins/discourse-mod/discourse/lib/linkify-message";

// Pure-function unit tests for the shared message renderer used by the
// precheck confirmation dialog and the category prompt preview. It escapes
// HTML, linkifies http(s) URLs, and preserves line breaks.

// htmlSafe wraps the string; .toString() / .string exposes the raw HTML.
function html(value) {
  const result = messageToHtml(value);
  return result.toString();
}

module("Unit | discourse-mod | linkify-message", function () {
  test("plain text passes through unchanged", function (assert) {
    assert.strictEqual(html("Read the rules"), "Read the rules");
  });

  test("blank inputs yield an empty string", function (assert) {
    assert.strictEqual(html(""), "");
    assert.strictEqual(html(null), "");
    assert.strictEqual(html(undefined), "");
  });

  test("escapes HTML special characters", function (assert) {
    assert.strictEqual(
      html("<script>alert('x')</script>"),
      "&lt;script&gt;alert('x')&lt;/script&gt;"
    );
  });

  test("escapes ampersands, quotes, angle brackets", function (assert) {
    assert.strictEqual(
      html(`a & b < c > d "quoted"`),
      `a &amp; b &lt; c &gt; d &quot;quoted&quot;`
    );
  });

  test("does not escape single quotes", function (assert) {
    assert.strictEqual(html("it's fine"), "it's fine");
  });

  test("linkifies an https URL", function (assert) {
    assert.strictEqual(
      html("See https://example.com/rules now"),
      'See <a href="https://example.com/rules" target="_blank" ' +
        'rel="noopener noreferrer">https://example.com/rules</a> now'
    );
  });

  test("linkifies an http URL", function (assert) {
    assert.strictEqual(
      html("http://example.com"),
      '<a href="http://example.com" target="_blank" ' +
        'rel="noopener noreferrer">http://example.com</a>'
    );
  });

  test("linkifies multiple URLs in one message", function (assert) {
    const result = html("a https://one.com b https://two.com c");
    assert.true(result.includes('href="https://one.com"'));
    assert.true(result.includes('href="https://two.com"'));
  });

  test("does not linkify a bare domain without a scheme", function (assert) {
    assert.strictEqual(html("visit example.com please"), "visit example.com please");
  });

  test("does not linkify ftp or other schemes", function (assert) {
    assert.strictEqual(html("ftp://example.com"), "ftp://example.com");
  });

  test("converts a unix newline to a br", function (assert) {
    assert.strictEqual(html("line one\nline two"), "line one<br>line two");
  });

  test("converts a windows CRLF newline to a single br", function (assert) {
    assert.strictEqual(html("line one\r\nline two"), "line one<br>line two");
  });

  test("converts multiple newlines to multiple brs", function (assert) {
    assert.strictEqual(html("a\nb\nc"), "a<br>b<br>c");
  });

  test("escapes HTML inside a linkified message", function (assert) {
    const result = html("<b>warn</b> https://example.com");
    assert.true(result.startsWith("&lt;b&gt;warn&lt;/b&gt; "));
    assert.true(result.includes('href="https://example.com"'));
  });

  test("a URL stops at whitespace", function (assert) {
    const result = html("https://example.com/path next-word");
    assert.true(result.includes(">https://example.com/path</a>"));
    assert.true(result.includes("</a> next-word"));
  });

  test("preserves unicode content", function (assert) {
    assert.strictEqual(html("🚀 проверка 名前"), "🚀 проверка 名前");
  });

  test("escaped angle bracket does not break a following URL", function (assert) {
    const result = html("a>b https://example.com");
    assert.true(result.startsWith("a&gt;b "));
    assert.true(result.includes('href="https://example.com"'));
  });

  test("a URL on its own line is linkified and the break kept", function (assert) {
    const result = html("Check this:\nhttps://example.com");
    assert.true(result.startsWith("Check this:<br>"));
    assert.true(result.includes('href="https://example.com"'));
  });
});
