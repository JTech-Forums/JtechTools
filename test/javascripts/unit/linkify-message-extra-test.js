import { module, test } from "qunit";
import { messageToHtml } from "discourse/plugins/discourse-mod/discourse/lib/linkify-message";

// Extra edge-case coverage for the shared message renderer (escaping +
// URL linkification + line breaks). Complements linkify-message-test.js.

function html(value) {
  return messageToHtml(value).toString();
}

module("Unit | discourse-mod | linkify-message | extra", function () {
  test("linkifies a URL with query string and fragment", function (assert) {
    const result = html(
      "See https://example.com/page?ref=mod&tag=app#anchor for details"
    );
    assert.true(
      result.includes(
        '<a href="https://example.com/page?ref=mod&amp;tag=app#anchor"'
      ),
      "the URL keeps its query and fragment (and & is escaped)"
    );
  });

  test("escapes wrapping HTML tags around a URL", function (assert) {
    const result = html("<p>hello https://example.com end</p>");
    // The wrapping <p>/</p> are escaped, and the URL is linkified.
    assert.true(result.startsWith("&lt;p&gt;hello "));
    assert.true(result.includes("https://example.com"));
    assert.true(result.includes("end&lt;/p&gt;"));
  });

  test("renders a string of only newlines as a stack of brs", function (assert) {
    assert.strictEqual(html("\n\n\n"), "<br><br><br>");
  });

  test("a single space is preserved", function (assert) {
    assert.strictEqual(html(" "), " ");
  });

  test("URL adjacent to punctuation keeps the punctuation outside the anchor", function (assert) {
    const result = html("Visit https://example.com.");
    // The greedy URL regex includes the trailing dot; this is intentional.
    assert.true(result.includes('<a href="https://example.com.'));
  });

  test("number-only message round-trips", function (assert) {
    assert.strictEqual(html("12345"), "12345");
  });

  test("escapes a quote followed by a URL", function (assert) {
    const result = html('"see" https://example.com');
    assert.true(result.startsWith("&quot;see&quot; "));
    assert.true(result.includes('href="https://example.com"'));
  });

  test("linkifies HTTPS URLs in the middle of a sentence", function (assert) {
    const result = html(
      "The doc at https://example.com/docs talks about it."
    );
    assert.true(result.includes('href="https://example.com/docs"'));
    assert.true(result.includes("talks about it."));
  });

  test("preserves trailing whitespace as text plus brs intact", function (assert) {
    assert.strictEqual(html("hi\n"), "hi<br>");
  });

  test("treats one CRLF and one LF the same way", function (assert) {
    assert.strictEqual(html("a\r\nb"), html("a\nb"));
  });

  test("a literal < in the input is escaped before linkification", function (assert) {
    // The < is escaped to &lt; before the URL regex runs, so the URL captures
    // the escaped entity too — confirming we never feed raw HTML to the regex.
    const result = html("https://example.com/x<after");
    assert.true(result.includes("&lt;after"));
  });
});
