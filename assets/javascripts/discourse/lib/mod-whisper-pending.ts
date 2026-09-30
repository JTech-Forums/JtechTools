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

// The body of a PUT to update_post_whisper.
export interface WhisperStatePayload {
  mod_whisper: boolean;
  mod_whisper_target_user_ids: number[];
  mod_whisper_target_group_ids: number[];
  mod_whisper_target_badge_ids: number[];
}

export interface PendingWhisperEdit {
  postId: number;
  state: WhisperStatePayload;
}

let pending: PendingWhisperEdit | null = null;

export function setPendingWhisperEdit(edit: PendingWhisperEdit): void {
  pending = edit;
}

export function takePendingWhisperEdit(): PendingWhisperEdit | null {
  const edit = pending;
  pending = null;
  return edit;
}

export function clearPendingWhisperEdit(): void {
  pending = null;
}
