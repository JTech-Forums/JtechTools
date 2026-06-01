import { i18n } from "discourse-i18n";

// Notification-type renderer for the moderator-note custom notification
// AND the staff-event streams that piggyback on the same `mod_note: true`
// marker (post actions, user notes, flag/reviewable notes).
//
// All plugin notifications share the `custom` notification type, so this
// renderer keys off the `mod_note` marker the server sets in the
// notification `data`. When the marker is absent (e.g. a whisper
// notification, also `custom`) every getter reproduces core's default
// `custom` notification behavior so other custom notifications are
// untouched. Registering a `custom` renderer replaces core's `custom.js`,
// so its `icon`/`linkTitle` logic is mirrored here for the fallback.

// Maps `mod_note_kind` → translation-key suffix in the
// `discourse_mod_categories` namespace. Falls back to "note" for both
// legacy rows (set before `mod_note_kind` existed) and any unknown
// future kind, so older rows always render as the original mod note.
const KIND_KEYS = {
  note: "note_notification",
  reply: "note_reply_notification",
  post_deleted: "post_deleted_notification",
  post_approved: "post_approved_notification",
  post_rejected: "post_rejected_notification",
  user_note: "user_note_notification",
  flag_note: "flag_note_notification",
};

export default function modNoteNotificationRenderer(NotificationTypeBase) {
  return class extends NotificationTypeBase {
    get isModNote() {
      return !!this.notification.data?.mod_note;
    }

    // "note" (default) vs "reply" / "post_deleted" / "post_approved" /
    // "post_rejected" / "user_note" / "flag_note" — every kind gets its
    // own label/title so the bell row reads accurately. Pre-`mod_note_kind`
    // rows (set before this field existed) are treated as the original note.
    get modNoteKind() {
      return this.notification.data?.mod_note_kind || "note";
    }

    get modNoteKey() {
      return KIND_KEYS[this.modNoteKind] || KIND_KEYS.note;
    }

    // Link straight to the target — note anchor on a topic, the post,
    // the user notes tab, or the review-queue entry, depending on kind.
    get linkHref() {
      if (this.isModNote && this.notification.data?.url) {
        return this.notification.data.url;
      }
      return super.linkHref;
    }

    get linkTitle() {
      if (this.isModNote) {
        return i18n(`discourse_mod_categories.${this.modNoteKey}_title`);
      }
      // Core `custom.js` behavior.
      if (this.notification.data?.title) {
        return i18n(this.notification.data.title);
      }
      return super.linkTitle;
    }

    // The plugin's registered shield icon, so the notification reads
    // unambiguously as a moderator/staff item.
    get icon() {
      if (this.isModNote) {
        return "shield-halved";
      }
      // Core `custom.js` behavior.
      return `notification.${this.notification.data?.message}`;
    }

    // Accurate, self-describing label naming the acting moderator —
    // e.g. "added a moderator note", "deleted a post", "added a note on a user".
    get label() {
      if (this.isModNote) {
        return i18n(`discourse_mod_categories.${this.modNoteKey}`, {
          username: this.username,
        });
      }
      return super.label;
    }

    // Second line: the excerpt (note body / post body / reply body)
    // when available, falling back to the topic title.
    get description() {
      if (this.isModNote) {
        return (
          this.notification.data?.excerpt || this.notification.data?.topic_title
        );
      }
      return super.description;
    }
  };
}
