import { i18n } from "discourse-i18n";

// Notification-type renderer for the moderator-note custom notification.
//
// All plugin notifications share the `custom` notification type, so this
// renderer keys off the `mod_note` marker the server sets in the
// notification `data`. When the marker is absent (e.g. a whisper
// notification, also `custom`) every getter reproduces core's default
// `custom` notification behavior so other custom notifications are
// untouched. Registering a `custom` renderer replaces core's `custom.js`,
// so its `icon`/`linkTitle` logic is mirrored here for the fallback.
export default function modNoteNotificationRenderer(NotificationTypeBase) {
  return class extends NotificationTypeBase {
    get isModNote() {
      return !!this.notification.data?.mod_note;
    }

    // "note" (default) vs "reply" — every reply in the note thread gets
    // its own notification row, so the renderer keys off this to label
    // and describe each one distinctly. Pre-`mod_note_kind` rows (set
    // before this field existed) are treated as the original note.
    get modNoteKind() {
      return this.notification.data?.mod_note_kind || "note";
    }

    // Link straight to the moderator note (or the specific reply) on the
    // topic — anchored with a `#mod-private-note[-reply-<id>]` hash that
    // the note component scrolls into view on insert.
    get linkHref() {
      if (this.isModNote && this.notification.data?.url) {
        return this.notification.data.url;
      }
      return super.linkHref;
    }

    get linkTitle() {
      if (this.isModNote) {
        return this.modNoteKind === "reply"
          ? i18n("discourse_mod_categories.note_reply_notification_title")
          : i18n("discourse_mod_categories.note_notification_title");
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
    // "added a moderator note" vs "replied to a moderator note".
    get label() {
      if (this.isModNote) {
        return this.modNoteKind === "reply"
          ? i18n("discourse_mod_categories.note_reply_notification", {
              username: this.username,
            })
          : i18n("discourse_mod_categories.note_notification", {
              username: this.username,
            });
      }
      return super.label;
    }

    // Second line: the reply excerpt (so stacked reply notifications are
    // self-describing) when available, falling back to the topic title.
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
