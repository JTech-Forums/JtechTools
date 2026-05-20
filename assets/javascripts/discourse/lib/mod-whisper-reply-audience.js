// Compute the reply audience for a moderator whisper: the original post's
// author plus every explicit target, deduplicated by id, minus the current
// user themself.
//
// Returns an array of { id, username, avatar_template } objects. Safe to call
// with any shape of post / currentUserId — returns [] when inputs are missing.
export function computeReplyAudience(post, currentUserId) {
  if (!post || !currentUserId) {
    return [];
  }
  const byId = new Map();
  const add = (id, username, avatarTemplate) => {
    if (!id || id === currentUserId) {
      return;
    }
    if (!byId.has(id)) {
      byId.set(id, { id, username, avatar_template: avatarTemplate });
    }
  };
  add(post.user_id, post.username, post.avatar_template);
  const targets = Array.isArray(post.mod_whisper_targets)
    ? post.mod_whisper_targets
    : [];
  targets.forEach((t) => {
    if (t && typeof t === "object") {
      add(t.id, t.username, t.avatar_template);
    }
  });
  return [...byId.values()];
}
