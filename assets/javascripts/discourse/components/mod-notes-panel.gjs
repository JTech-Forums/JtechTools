import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

// Maps `kind` → translation-key suffix in the `discourse_mod_categories`
// namespace, mirroring KIND_KEYS in lib/mod-note-notification.js so the
// shield-tab labels match the bell-tab labels for every kind. Unknown /
// legacy kinds fall back to the original "note" label.
const KIND_KEYS = {
  note: "note_notification",
  reply: "note_reply_notification",
  post_deleted: "post_deleted_notification",
  post_approved: "post_approved_notification",
  post_rejected: "post_rejected_notification",
  user_note: "user_note_notification",
  flag_note: "flag_note_notification",
};

function labelFor(note) {
  // Legacy topic-attached entries (returned from the topic-custom-field
  // path of notes_feed) carry no `username` — fall back to the topic
  // title alone so the row reads cleanly instead of as " added a
  // moderator note" with a leading space.
  if (!note.username) {
    return note.topic_title || "";
  }
  const key = KIND_KEYS[note.kind] || KIND_KEYS.note;
  return i18n(`discourse_mod_categories.${key}`, { username: note.username });
}

// Context line under the label — topic title for topic-anchored kinds,
// "on <target_username>" for user-note / flag-note kinds, otherwise blank.
function contextFor(note) {
  if (note.topic_title) {
    return note.topic_title;
  }
  if (note.target_username) {
    return i18n("discourse_mod_categories.notes_tab.on_target", {
      target: note.target_username,
    });
  }
  return "";
}

// Panel rendered inside the staff "Moderator notes" user-menu tab.
// Mirrors the bell's mod-note rows exactly — same notifications, same
// labels — so a staff member can use either entry point interchangeably.
export default class ModNotesPanel extends Component {
  @service currentUser;

  @tracked notes = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    try {
      const result = await ajax("/discourse-mod-categories/notes-feed.json");
      this.notes = result.notes || [];
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }

    try {
      await ajax("/discourse-mod-categories/notes-feed/seen.json", {
        type: "POST",
      });
      this.currentUser?.set("mod_note_unread_count", 0);
    } catch {
      // Marking the feed as seen is best-effort.
    }
  }

  labelFor = labelFor;
  contextFor = contextFor;

  <template>
    <div class="mod-notes-panel">
      {{#if this.loading}}
        <div class="mod-notes-empty">
          {{i18n "discourse_mod_categories.notes_tab.loading"}}
        </div>
      {{else if this.notes.length}}
        <ul class="mod-notes-list">
          {{#each this.notes as |note|}}
            <li
              class="mod-notes-item {{if note.unread 'mod-notes-item--unread'}}"
            >
              <a href={{note.url}} class="mod-notes-item-link">
                {{icon "shield-halved"}}
                <span class="mod-notes-item-body">
                  <span class="mod-notes-item-title">
                    {{this.labelFor note}}
                  </span>
                  {{#let (this.contextFor note) as |ctx|}}
                    {{#if ctx}}
                      <span class="mod-notes-item-context">{{ctx}}</span>
                    {{/if}}
                  {{/let}}
                  {{#if note.excerpt}}
                    <span class="mod-notes-item-note">{{note.excerpt}}</span>
                  {{/if}}
                </span>
              </a>
            </li>
          {{/each}}
        </ul>
      {{else}}
        <div class="mod-notes-empty">
          {{i18n "discourse_mod_categories.notes_tab.empty"}}
        </div>
      {{/if}}
    </div>
  </template>
}
