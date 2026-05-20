import { module, test } from "qunit";
import { CREATE_TOPIC } from "discourse/models/composer";
import {
  precheckPromptFor,
  REPLY_ACTION,
} from "discourse/plugins/discourse-mod/discourse/lib/precheck-prompt";

// Exhaustive matrix coverage for the composer precheck prompt resolution.
// Pure-function unit tests; end-to-end behaviour is in spec/system.

const PROMPTS = [
  { label: "undefined", value: undefined, blank: true },
  { label: "null", value: null, blank: true },
  { label: "empty", value: "", blank: true },
  { label: "spaces", value: "   ", blank: true },
  { label: "tab", value: "\t", blank: true },
  { label: "newline", value: "\n", blank: true },
  { label: "mixed-ws", value: " \n\t ", blank: true },
  { label: "text", value: "Read the rules", trimmed: "Read the rules" },
  {
    label: "padded",
    value: "  Read the rules  ",
    trimmed: "Read the rules",
  },
  {
    label: "app-warning",
    value:
      "Is this an app upload or link to an app? If it's just a comment or question, please post somewhere else.",
    trimmed:
      "Is this an app upload or link to an app? If it's just a comment or question, please post somewhere else.",
  },
  { label: "html", value: "<b>careful</b>", trimmed: "<b>careful</b>" },
  { label: "unicode", value: "🚀 проверка 名前", trimmed: "🚀 проверка 名前" },
  { label: "long", value: "x".repeat(800), trimmed: "x".repeat(800) },
  { label: "digit", value: "0", trimmed: "0" },
];

module("Unit | discourse-mod | precheck-prompt | new topic", function () {
  [true, false].forEach((enabled) => {
    [true, false].forEach((replyFlag) => {
      PROMPTS.forEach((p) => {
        const expected = enabled && !p.blank ? p.trimmed : null;
        test(`enabled=${enabled} replyFlag=${replyFlag} prompt=${p.label}`, function (assert) {
          const composer = {
            action: CREATE_TOPIC,
            category: { mod_category_new_topic_prompt: p.value },
            topic: { mod_topic_reply_prompt: "should be ignored" },
          };
          const siteSettings = {
            precheck_new_topic_enabled: enabled,
            topic_reply_prompt_enabled: replyFlag,
          };
          assert.strictEqual(
            precheckPromptFor(composer, siteSettings),
            expected
          );
        });
      });
    });
  });

  test("no category resolves to null", function (assert) {
    assert.strictEqual(
      precheckPromptFor(
        { action: CREATE_TOPIC },
        { precheck_new_topic_enabled: true }
      ),
      null
    );
  });

  test("null composer resolves to null", function (assert) {
    assert.strictEqual(
      precheckPromptFor(null, { precheck_new_topic_enabled: true }),
      null
    );
  });

  test("null siteSettings resolves to null", function (assert) {
    assert.strictEqual(
      precheckPromptFor({ action: CREATE_TOPIC }, null),
      null
    );
  });
});

module("Unit | discourse-mod | precheck-prompt | reply", function () {
  [true, false].forEach((enabled) => {
    [true, false].forEach((newTopicFlag) => {
      PROMPTS.forEach((p) => {
        const expected = enabled && !p.blank ? p.trimmed : null;
        test(`enabled=${enabled} newTopicFlag=${newTopicFlag} prompt=${p.label}`, function (assert) {
          const composer = {
            action: REPLY_ACTION,
            topic: { mod_topic_reply_prompt: p.value },
            category: { mod_category_new_topic_prompt: "should be ignored" },
          };
          const siteSettings = {
            topic_reply_prompt_enabled: enabled,
            precheck_new_topic_enabled: newTopicFlag,
          };
          assert.strictEqual(
            precheckPromptFor(composer, siteSettings),
            expected
          );
        });
      });
    });
  });

  test("no topic resolves to null", function (assert) {
    assert.strictEqual(
      precheckPromptFor(
        { action: REPLY_ACTION },
        { topic_reply_prompt_enabled: true }
      ),
      null
    );
  });

  test("REPLY_ACTION constant is 'reply'", function (assert) {
    assert.strictEqual(REPLY_ACTION, "reply");
  });
});

module(
  "Unit | discourse-mod | precheck-prompt | other actions",
  function () {
    ["edit", "privateMessage", "editSharedDraft", "", null, undefined].forEach(
      (action) => {
        test(`action=${JSON.stringify(action)} is never gated`, function (assert) {
          const composer = {
            action,
            category: { mod_category_new_topic_prompt: "x" },
            topic: { mod_topic_reply_prompt: "y" },
          };
          assert.strictEqual(
            precheckPromptFor(composer, {
              precheck_new_topic_enabled: true,
              topic_reply_prompt_enabled: true,
            }),
            null
          );
        });
      }
    );
  }
);

module(
  "Unit | discourse-mod | precheck-prompt | advanced scenarios",
  function () {
    test("new topic uses the category prompt, ignores the topic prompt", function (assert) {
      const composer = {
        action: CREATE_TOPIC,
        category: { mod_category_new_topic_prompt: "CATEGORY MESSAGE" },
        topic: { mod_topic_reply_prompt: "TOPIC MESSAGE" },
      };
      assert.strictEqual(
        precheckPromptFor(composer, {
          precheck_new_topic_enabled: true,
          topic_reply_prompt_enabled: true,
        }),
        "CATEGORY MESSAGE"
      );
    });

    test("reply uses the topic prompt, ignores the category prompt", function (assert) {
      const composer = {
        action: REPLY_ACTION,
        category: { mod_category_new_topic_prompt: "CATEGORY MESSAGE" },
        topic: { mod_topic_reply_prompt: "TOPIC MESSAGE" },
      };
      assert.strictEqual(
        precheckPromptFor(composer, {
          precheck_new_topic_enabled: true,
          topic_reply_prompt_enabled: true,
        }),
        "TOPIC MESSAGE"
      );
    });

    test("new topic not gated when only the reply feature is on", function (assert) {
      assert.strictEqual(
        precheckPromptFor(
          {
            action: CREATE_TOPIC,
            category: { mod_category_new_topic_prompt: "X" },
          },
          { topic_reply_prompt_enabled: true }
        ),
        null
      );
    });

    test("reply not gated when only the new-topic feature is on", function (assert) {
      assert.strictEqual(
        precheckPromptFor(
          { action: REPLY_ACTION, topic: { mod_topic_reply_prompt: "X" } },
          { precheck_new_topic_enabled: true }
        ),
        null
      );
    });

    [
      ["  spaced  ", "spaced"],
      ["\ttabbed\t", "tabbed"],
      ["\nline\n", "line"],
      ["no-trim-needed", "no-trim-needed"],
    ].forEach(([input, expected]) => {
      test(`new topic trims ${JSON.stringify(input)}`, function (assert) {
        assert.strictEqual(
          precheckPromptFor(
            {
              action: CREATE_TOPIC,
              category: { mod_category_new_topic_prompt: input },
            },
            { precheck_new_topic_enabled: true }
          ),
          expected
        );
      });

      test(`reply trims ${JSON.stringify(input)}`, function (assert) {
        assert.strictEqual(
          precheckPromptFor(
            { action: REPLY_ACTION, topic: { mod_topic_reply_prompt: input } },
            { topic_reply_prompt_enabled: true }
          ),
          expected
        );
      });
    });

    test("extra unrelated siteSettings keys do not affect the result", function (assert) {
      assert.strictEqual(
        precheckPromptFor(
          {
            action: CREATE_TOPIC,
            category: { mod_category_new_topic_prompt: "Y" },
          },
          {
            precheck_new_topic_enabled: true,
            some_other_setting: true,
            foo: "bar",
          }
        ),
        "Y"
      );
    });

    test("category present but missing the prompt field resolves to null", function (assert) {
      assert.strictEqual(
        precheckPromptFor(
          { action: CREATE_TOPIC, category: {} },
          { precheck_new_topic_enabled: true }
        ),
        null
      );
    });

    test("topic present but missing the prompt field resolves to null", function (assert) {
      assert.strictEqual(
        precheckPromptFor(
          { action: REPLY_ACTION, topic: {} },
          { topic_reply_prompt_enabled: true }
        ),
        null
      );
    });
  }
);

module(
  "Unit | discourse-mod | precheck-prompt | trust-level cap",
  function () {
    // maxTl is the highest trust level still prompted. A user is exempt
    // only when their trust level is strictly above the cap.
    const CASES = [
      // [maxTl, userTl, prompted?]
      [undefined, 0, true],
      [undefined, 4, true],
      [4, 0, true],
      [4, 4, true],
      ["", 0, true],
      [0, 0, true],
      [0, 1, false],
      [0, 4, false],
      [1, 0, true],
      [1, 1, true],
      [1, 2, false],
      [1, 3, false],
      [2, 2, true],
      [2, 3, false],
      [3, 3, true],
      [3, 4, false],
      ["1", 2, false],
      ["1", 1, true],
    ];

    CASES.forEach(([maxTl, userTl, prompted]) => {
      test(`reply maxTl=${maxTl} userTl=${userTl} prompted=${prompted}`, function (assert) {
        const result = precheckPromptFor(
          {
            action: REPLY_ACTION,
            topic: {
              mod_topic_reply_prompt: "Read the rules",
              mod_topic_reply_prompt_max_tl: maxTl,
            },
          },
          { topic_reply_prompt_enabled: true },
          { trust_level: userTl }
        );
        assert.strictEqual(result, prompted ? "Read the rules" : null);
      });

      test(`new topic maxTl=${maxTl} userTl=${userTl} prompted=${prompted}`, function (assert) {
        const result = precheckPromptFor(
          {
            action: CREATE_TOPIC,
            category: {
              mod_category_new_topic_prompt: "Read the rules",
              mod_category_new_topic_prompt_max_tl: maxTl,
            },
          },
          { precheck_new_topic_enabled: true },
          { trust_level: userTl }
        );
        assert.strictEqual(result, prompted ? "Read the rules" : null);
      });
    });

    test("a cap with no current user still prompts", function (assert) {
      assert.strictEqual(
        precheckPromptFor(
          {
            action: REPLY_ACTION,
            topic: {
              mod_topic_reply_prompt: "Read the rules",
              mod_topic_reply_prompt_max_tl: 1,
            },
          },
          { topic_reply_prompt_enabled: true }
        ),
        "Read the rules"
      );
    });
  }
);
