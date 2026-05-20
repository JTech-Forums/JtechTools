import { module, test } from "qunit";
import {
  shouldRenderTopicFooterMessage,
  topicFooterFeatureActive,
  topicFooterMessage,
} from "discourse/plugins/discourse-mod/discourse/lib/topic-footer-message";

// Exhaustive matrix coverage for the moderator-set bottom-pinned message
// visibility decision (reads the topic's mod_topic_footer_message custom
// field). Pure-function unit tests; rendering is covered by spec/system.

const MESSAGES = [
  { label: "undefined", value: undefined, blank: true },
  { label: "null", value: null, blank: true },
  { label: "empty", value: "", blank: true },
  { label: "spaces", value: "   ", blank: true },
  { label: "tab", value: "\t", blank: true },
  { label: "newline", value: "\n", blank: true },
  { label: "mixed-ws", value: " \n\t ", blank: true },
  { label: "text", value: "Read the pinned guidelines", blank: false },
  { label: "padded", value: "  hello  ", blank: false },
  { label: "html", value: "<strong>Hi</strong>", blank: false },
  { label: "long", value: "x".repeat(2000), blank: false },
  { label: "unicode", value: "🚀 μνιςωδε", blank: false },
  { label: "digit", value: "0", blank: false },
  { label: "script-ish", value: "<script>x()</script>", blank: false },
];

const TOPICS = [
  { label: "regular", archetype: "regular", render: true },
  { label: "no-archetype", archetype: undefined, render: true },
  { label: "banner", archetype: "banner", render: true },
  { label: "private_message", archetype: "private_message", render: false },
];

const ENABLED = [
  { label: "true", value: true, on: true },
  { label: "false", value: false, on: false },
  { label: "absent", value: undefined, on: false },
];

module(
  "Unit | discourse-mod | topic-footer-message | shouldRender",
  function () {
    ENABLED.forEach((en) => {
      MESSAGES.forEach((msg) => {
        TOPICS.forEach((t) => {
          const expected = en.on && !msg.blank && t.render;
          test(`enabled=${en.label} msg=${msg.label} topic=${t.label} => ${expected}`, function (assert) {
            const siteSettings = { topic_footer_message_enabled: en.value };
            const topic = {
              archetype: t.archetype,
              mod_topic_footer_message: msg.value,
            };
            assert.strictEqual(
              shouldRenderTopicFooterMessage(siteSettings, topic),
              expected
            );
          });
        });
      });
    });

    test("null topic returns false", function (assert) {
      assert.false(
        shouldRenderTopicFooterMessage(
          { topic_footer_message_enabled: true },
          null
        )
      );
    });

    test("undefined topic returns false", function (assert) {
      assert.false(
        shouldRenderTopicFooterMessage(
          { topic_footer_message_enabled: true },
          undefined
        )
      );
    });

    test("null siteSettings returns false", function (assert) {
      assert.false(
        shouldRenderTopicFooterMessage(null, {
          archetype: "regular",
          mod_topic_footer_message: "hi",
        })
      );
    });
  }
);

module(
  "Unit | discourse-mod | topic-footer-message | topicFooterMessage",
  function () {
    MESSAGES.forEach((msg) => {
      const expected = msg.blank ? "" : msg.value.trim();
      test(`message=${msg.label} trims to expected`, function (assert) {
        assert.strictEqual(
          topicFooterMessage({ mod_topic_footer_message: msg.value }),
          expected
        );
      });
    });

    test("null topic yields empty string", function (assert) {
      assert.strictEqual(topicFooterMessage(null), "");
    });

    test("undefined topic yields empty string", function (assert) {
      assert.strictEqual(topicFooterMessage(undefined), "");
    });

    test("topic without the field yields empty string", function (assert) {
      assert.strictEqual(topicFooterMessage({}), "");
    });
  }
);

module(
  "Unit | discourse-mod | topic-footer-message | topicFooterFeatureActive",
  function () {
    // The structural gate is independent of the message text, so the
    // connector can render and decide reactively whether to show the box.
    ENABLED.forEach((en) => {
      TOPICS.forEach((t) => {
        ["", "   ", "a message", undefined, null].forEach((msg, i) => {
          const expected = en.on && t.render;
          test(`enabled=${en.label} topic=${t.label} msg#${i} => ${expected}`, function (assert) {
            const siteSettings = { topic_footer_message_enabled: en.value };
            const topic = {
              archetype: t.archetype,
              mod_topic_footer_message: msg,
            };
            assert.strictEqual(
              topicFooterFeatureActive(siteSettings, topic),
              expected
            );
          });
        });
      });
    });

    test("null topic returns false", function (assert) {
      assert.false(
        topicFooterFeatureActive({ topic_footer_message_enabled: true }, null)
      );
    });

    test("null siteSettings returns false", function (assert) {
      assert.false(topicFooterFeatureActive(null, { archetype: "regular" }));
    });
  }
);

module(
  "Unit | discourse-mod | topic-footer-message | advanced scenarios",
  function () {
    test("HTML message is returned verbatim (trimmed) for trusted rendering", function (assert) {
      assert.strictEqual(
        topicFooterMessage({
          mod_topic_footer_message:
            "  <b>Bold</b> and <a href='#'>a link</a>  ",
        }),
        "<b>Bold</b> and <a href='#'>a link</a>"
      );
    });

    test("feature stays active whether or not a message is present", function (assert) {
      const settings = { topic_footer_message_enabled: true };
      assert.true(
        topicFooterFeatureActive(settings, {
          archetype: "regular",
          mod_topic_footer_message: "",
        })
      );
      assert.true(
        topicFooterFeatureActive(settings, {
          archetype: "regular",
          mod_topic_footer_message: "a message",
        })
      );
    });

    test("overall visibility needs the gate AND a non-blank message", function (assert) {
      const settings = { topic_footer_message_enabled: true };
      assert.false(
        shouldRenderTopicFooterMessage(settings, {
          archetype: "regular",
          mod_topic_footer_message: "   ",
        })
      );
      assert.true(
        shouldRenderTopicFooterMessage(settings, {
          archetype: "regular",
          mod_topic_footer_message: "visible",
        })
      );
    });

    test("private messages never activate the feature", function (assert) {
      assert.false(
        topicFooterFeatureActive(
          { topic_footer_message_enabled: true },
          { archetype: "private_message", mod_topic_footer_message: "hi" }
        )
      );
    });

    test("disabled feature is never active", function (assert) {
      assert.false(
        topicFooterFeatureActive(
          { topic_footer_message_enabled: false },
          { archetype: "regular", mod_topic_footer_message: "hi" }
        )
      );
    });
  }
);
