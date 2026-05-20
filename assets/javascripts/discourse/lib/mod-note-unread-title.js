// Pure helpers for the moderator-notes browser-tab title prefix.
//
// `applyUnreadPrefix(title, count)` mirrors how the bell prefixes the
// document title with `(N)` when there are unread items. It is intentionally
// idempotent: any existing `(N)` prefix is stripped before a new one is
// applied, so repeated calls (or a count that ticks back down to zero) leave
// the title in the right shape.

const PREFIX_RE = /^\(\d+\)\s+/;

// Returns the title with an existing `(N)` prefix removed, if any.
export function stripUnreadPrefix(title) {
  return (title || "").replace(PREFIX_RE, "");
}

// Returns `(count) title` when count > 0, else the bare title. The input
// title is first stripped of any prefix so repeated calls do not stack.
export function applyUnreadPrefix(title, count) {
  const base = stripUnreadPrefix(title);
  const n = Math.max(0, parseInt(count, 10) || 0);
  if (n <= 0) {
    return base;
  }
  return `(${n}) ${base}`;
}
