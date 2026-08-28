// Hand-off between the whisper-target modal and the mod-whisper
// initializer for the EDIT flow. Discourse's PostsController#update drops
// whisper params, so a staff edit that touched the whisper state needs a
// follow-up PUT to the plugin's update_post_whisper endpoint after the
// edit save resolves.
//
// The modal records the intended state here at confirm/clear time (while
// it still holds a live composer reference), and the initializer flushes
// it on `composer:saved` — the one composer app event guaranteed to fire
// on every successful save. Storing the full state up front means the
// flush never has to re-inspect the composer model, which may already be
// tearing down by the time the event handlers run.
//
// At most one edit is pending at a time: the composer is modal per tab,
// and `composer:opened` clears any leftover from a cancelled edit.

let pending = null;

export function setPendingWhisperEdit(edit) {
  pending = edit;
}

export function takePendingWhisperEdit() {
  const edit = pending;
  pending = null;
  return edit;
}

export function clearPendingWhisperEdit() {
  pending = null;
}
