import { ajax } from "discourse/lib/ajax";
import { CREATE_TOPIC } from "discourse/models/composer";
import { REPLY_ACTION } from "./precheck-prompt";

// The first-post checklist the current user must complete before this
// composer save, or null when nothing should gate it.
//
// `currentUser.mod_first_post_checklist` carries the owed checklist. It is
// bootstrapped on a full page load, but Discourse is a single-page app, so
// after the user accepts once (which clears it to null) or staff bump the
// version mid-session, the bootstrapped value goes stale. `refreshOwedChecklist`
// re-syncs it from the server when the composer opens, so the gate below
// always reads the CURRENT server state — no hard page refresh needed.
export function firstPostChecklistFor(composer, currentUser) {
  if (!composer || !currentUser) {
    return null;
  }

  if (composer.action !== CREATE_TOPIC && composer.action !== REPLY_ACTION) {
    return null;
  }

  const checklist = currentUser.mod_first_post_checklist;
  if (!checklist) {
    return null;
  }

  // Statement mode has no items by design — a non-blank statement is
  // what makes it active. Other modes require at least one item.
  if (checklist.mode === "statement") {
    if (!checklist.statement || !checklist.statement.trim()) {
      return null;
    }
    return checklist;
  }

  if (!checklist.items || checklist.items.length === 0) {
    return null;
  }

  return checklist;
}

// The id of the topic being replied to in this composer (or null when the
// composer is creating a new topic). The per-topic checklist gate keys on
// this so the server can include the topic-scoped checklist in the owed
// result.
export function composerTopicId(composer) {
  if (!composer) {
    return null;
  }
  if (composer.action !== REPLY_ACTION) {
    return null;
  }
  const topic = composer.topic;
  return topic && topic.id ? topic.id : null;
}

// Re-fetches the current user's currently-owed checklist from the server
// and writes it onto `currentUser.mod_first_post_checklist`, so a checklist
// edited or version-bumped mid-session is gated without a hard refresh.
// Returns a promise; a failed request leaves the existing value untouched.
//
// When `topicId` is provided the server also considers the per-topic
// prompt checklist for that topic; priority is targeted > per-topic >
// global, so a user owing several is shown the highest-priority one.
export function refreshOwedChecklist(currentUser, topicId = null) {
  if (!currentUser) {
    return Promise.resolve();
  }

  const url = topicId
    ? `/discourse-mod-categories/checklist/owed.json?topic_id=${encodeURIComponent(
        topicId
      )}`
    : "/discourse-mod-categories/checklist/owed.json";

  return ajax(url)
    .then((result) => {
      currentUser.set("mod_first_post_checklist", result?.checklist ?? null);
    })
    .catch(() => {
      // Network error: keep whatever value we already have rather than
      // dropping a checklist the user genuinely owes.
    });
}
