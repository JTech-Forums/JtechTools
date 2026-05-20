import { CREATE_TOPIC } from "discourse/models/composer";

// Composer action string for a reply (Composer.REPLY).
export const REPLY_ACTION = "reply";

export const PRECHECK_TITLE_KEY = "discourse_mod_categories.precheck.title";
export const PRECHECK_CONFIRM_KEY = "discourse_mod_categories.precheck.confirm";
export const PRECHECK_GO_BACK_KEY = "discourse_mod_categories.precheck.go_back";

function nonBlank(value) {
  const trimmed = (value || "").trim();
  return trimmed.length > 0 ? trimmed : null;
}

// True when this user is established enough to skip the prompt. `maxTl` is
// the highest trust level a moderator still wants prompted (0-3); blank or
// 4 means everyone is prompted, so nobody is exempt.
function trustLevelExempt(currentUser, maxTl) {
  if (maxTl === null || maxTl === undefined || maxTl === "") {
    return false;
  }
  const cap = parseInt(maxTl, 10);
  if (isNaN(cap) || cap >= 4) {
    return false;
  }
  const tl = currentUser && currentUser.trust_level;
  if (tl === null || tl === undefined) {
    return false;
  }
  return tl > cap;
}

// Returns the confirmation message to show before this composer save, or
// null when nothing should gate the save.
//
// - New topic: uses the `mod_category_new_topic_prompt` set by a
//   moderator on the chosen category (feature gated by
//   precheck_new_topic_enabled).
// - Reply: uses the `mod_topic_reply_prompt` set by a moderator on the
//   topic being replied to (feature gated by topic_reply_prompt_enabled).
//
// A moderator can also cap the prompt by trust level: when the matching
// `*_max_tl` field is set to 0-3, users above that trust level skip it.
export function precheckPromptFor(composer, siteSettings, currentUser) {
  if (!composer || !siteSettings) {
    return null;
  }

  if (composer.action === CREATE_TOPIC) {
    if (!siteSettings.precheck_new_topic_enabled) {
      return null;
    }
    const category = composer.category;
    if (!category) {
      return null;
    }
    if (
      trustLevelExempt(
        currentUser,
        category.mod_category_new_topic_prompt_max_tl
      )
    ) {
      return null;
    }
    return nonBlank(category.mod_category_new_topic_prompt);
  }

  if (composer.action === REPLY_ACTION) {
    if (!siteSettings.topic_reply_prompt_enabled) {
      return null;
    }
    const topic = composer.topic;
    if (!topic) {
      return null;
    }
    if (trustLevelExempt(currentUser, topic.mod_topic_reply_prompt_max_tl)) {
      return null;
    }
    return nonBlank(topic.mod_topic_reply_prompt);
  }

  return null;
}
