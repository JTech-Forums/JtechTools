# Disteleplus Native Chat Independence Plan

## Objective

Make Disteleplus completely independent of the official Discourse Chat plugin.
After this work, an administrator can disable Discourse Chat while retaining a
single, first-class conversation inside Discourse that bridges bidirectionally
with the configured Telegram group/topic.

The finished feature is intentionally a focused single-room messenger, not a
replacement general-purpose chat platform. It retains the functionality that
matters to the bridge without adding channels, direct messages, threads,
presence, calls, or workspace administration.

## Product Scope

### Retain

- One shared Disteleplus conversation.
- Telegram-to-Discourse and Discourse-to-Telegram text messages.
- Telegram user to Discourse user mapping.
- A bridge-bot fallback for unmapped Telegram users.
- Replies.
- Edits and deletions where Telegram permits them.
- Reactions, with the existing Telegram Bot API asymmetry.
- Photos, video, audio, voice notes, documents, and other uploads.
- Telegram polls rendered in the conversation.
- Existing waveform voice-note player and browser recorder.
- Per-user unread state and a shortcut badge.
- Live updates without refreshing the page.
- Browser and web-push notifications using Discourse infrastructure.
- Mobile and desktop layouts.
- Existing Telegram setup commands and forum-upload archive stream.

### Deliberately Exclude

- Multiple channels or rooms.
- Direct messages.
- Chat threads. Message replies remain supported.
- Presence and typing indicators.
- Voice or video calls.
- General chat discovery or membership administration.

## Architectural Decision

Build the UI natively with Discourse's Ember/Glimmer frontend rather than
embedding React. Chatscope's MIT-licensed Chat UI Kit may be used as a visual
reference, but its React runtime and state model will not be introduced into
the Discourse application.

The native route will be `/disteleplus`. A dedicated header shortcut and
unread badge will open that route. Nothing will intercept the official Chat
button or use `/chat` routes.

All message mutations will pass through one plugin-owned service so Telegram
webhooks, authenticated API requests, realtime publication, unread state,
notifications, and outbound Telegram jobs observe the same behavior.

## Target Data Flow

```text
Telegram webhook
      |
      v
Disteleplus::MessageService
      |
      +--> plugin-owned message/upload/reaction tables
      +--> private MessageBus publication
      +--> unread/notification fan-out
      v
/disteleplus native UI

Discourse user composer
      |
      v
Disteleplus authenticated API
      |
      v
Disteleplus::MessageService
      |
      +--> native persistence/realtime/notifications
      +--> Sidekiq outbound Telegram job
```

## Persistence

### `disteleplus_messages`

- `id`
- `user_id`, nullable only when imported data cannot resolve an author
- `raw`, allowing upload-only messages
- `cooked`, produced server-side through Discourse's safe cooking pipeline
- `source` enum: `discourse` or `telegram`
- `external_sender_name`, used for an unmapped Telegram identity
- `reply_to_id`, self-referential and nullable
- `edited_at`
- `deleted_at`
- timestamps

Messages use soft deletion so clients can retain reply structure and render a
deleted placeholder. Author and reply indexes support authorization and
timeline serialization.

### `disteleplus_message_uploads`

- `message_id`
- `upload_id`
- unique composite index

This join preserves durable upload references and supports multi-upload
messages without storing an array in a message row.

### `disteleplus_reactions`

- `message_id`
- `user_id`
- normalized Discourse emoji name
- timestamps
- unique index on message, user, and emoji

### `disteleplus_user_states`

- `user_id`, unique
- `last_read_message_id`, nullable
- notification level for this conversation if the forced-notification setting
  is later relaxed
- timestamps

### Existing link table

Add `disteleplus_message_id` to `disteleplus_message_links`. Keep
`chat_message_id` nullable during the compatibility window. New bridge writes
use the native message ID; legacy Chat IDs remain only to support import audit
and rollback.

## Permission Model

- Add `disteleplus_allowed_groups`, defaulting to staff unless explicitly
  configured otherwise.
- Administrators always retain access while the feature is enabled.
- Every controller action checks a plugin-owned Guardian predicate.
- Every MessageBus publication is scoped to explicitly authorized user IDs or
  a secure group-based channel supported by Discourse.
- Authors can edit/delete their own messages; staff can moderate all messages.
- Telegram-origin messages are not editable/deletable from Discourse when the
  bot cannot perform the equivalent Telegram action.
- Apply Discourse rate limiting to create, edit, reaction, and mark-read
  endpoints.
- Cook message text server-side and never trust client HTML.
- Validate that attached uploads exist and are owned by or accessible to the
  posting user before associating them.

## API

Authenticated routes under `/jtech-disteleplus`:

- `GET /conversation` returns current user state and an initial message page.
- `GET /messages?before_id=<id>&limit=<n>` provides cursor pagination.
- `POST /messages` creates text/upload/reply messages.
- `PUT /messages/:id` edits a message.
- `DELETE /messages/:id` soft-deletes a message.
- `PUT /messages/:id/reactions/:emoji` adds a reaction.
- `DELETE /messages/:id/reactions/:emoji` removes a reaction.
- `POST /read` advances the current user's read cursor monotonically.
- `POST /legacy-import` starts or resumes the administrator-only Chat import.
- `GET /legacy-import` returns import counts and audit status.

Responses use a dedicated serializer including author, avatar template,
source, external sender, cooked body, uploads, reply preview, reaction groups,
permissions, timestamps, and deletion/edit state.

## Realtime and Unread State

- Publish `created`, `edited`, `deleted`, and `reaction_changed` events through
  MessageBus after a successful database transaction.
- Subscribe from a Glimmer service/component only when the current user is
  authorized.
- Calculate unread count as visible message IDs after the user's last-read
  cursor, excluding messages authored by that user.
- Mark read when the route is visible and the latest message has entered the
  timeline.
- Expose unread count to the shortcut badge at application boot and update it
  from MessageBus events.
- Guard against backlog replay and duplicate event application by message ID.

## Notifications

- Replace Chat memberships and notification levels with a Disteleplus
  notifier.
- Reuse Discourse Notification records and existing push subscriptions where
  possible.
- Notify only authorized active users.
- Exclude the author and bridge bot.
- Avoid a desktop alert when the recipient is actively viewing the
  conversation, while still maintaining unread correctness in other tabs.
- Publish notification state so existing header/browser notification
  mechanisms update immediately.
- Preserve the existing forced-notification setting semantically, but remove
  every dependency on `Chat::UserChatChannelMembership` and `chat_enabled`.

## Native UI

### Route and shell

- Add a main-bundle route map for `/disteleplus`.
- Add a route, controller/service as needed, and one top-level Glimmer page.
- Render a responsive full-height conversation within Discourse's application
  shell.

### Timeline

- Cursor pagination when scrolling upward.
- Stable scroll anchoring when older messages are prepended.
- Auto-scroll only when the user is already near the bottom.
- New-message indicator when live messages arrive while scrolled upward.
- Date separators and unread divider.
- Discourse avatars and profile links for mapped users.
- Clear Telegram marker and sender name for unmapped senders.
- Reply preview and jump-to-message behavior.
- Edited and deleted states.
- Accessible action menu and reaction controls.

### Composer

- Multiline text with send button and keyboard handling.
- Core `/uploads.json` upload flow using a Disteleplus-specific upload type.
- Attachment previews and removal before send.
- Reply and edit banners.
- Reuse the existing voice recorder, changing its final POST from the Chat API
  to the native message endpoint.
- Disable submission while uploading/sending and surface API errors.

### Media

- Images and video inline with safe dimensions.
- Documents as download cards.
- Audio and voice notes through the existing waveform player.
- Upload-only messages supported.
- Existing secure-upload behavior respected.

### Shortcut

- Add a dedicated header icon labeled Disteleplus.
- Display the server-derived unread badge.
- Link directly to `/disteleplus`.
- Do not depend on `.chat-header-icon`, Chat drawer services, Chat route names,
  or Chat composer plugin APIs.

## Telegram Bridge Rewire

- Replace `ChatAdapter` operations with native message-service operations.
- Telegram inbound creates native messages directly.
- Preserve matched-user posting and bot fallback semantics.
- Store `external_sender_name` structurally instead of detecting a bold text
  prefix in rendered HTML.
- Telegram edits update native messages.
- Telegram poll state updates native message content.
- Telegram reactions update native reaction rows.
- Outbound jobs load native messages and native uploads/reactions.
- Native create/edit/delete/reaction operations enqueue the outbound job
  directly after commit; they no longer observe Chat DiscourseEvents.
- Preserve durable echo suppression through the link table.
- Continue treating Telegram-side deletion as unknowable because bots do not
  receive deletion updates.

## Legacy Chat Import

The import runs only while Discourse Chat is available and never deletes or
modifies old Chat records.

1. Read the configured legacy channel in ascending message-ID order.
2. Import in bounded resumable batches.
3. Preserve user, raw text, created/edited/deleted timestamps, replies,
   uploads, and reactions where available.
4. Record the source Chat ID on the link/audit data to make reruns idempotent.
5. Translate existing Telegram link rows to the new native message IDs.
6. Report source count, imported count, skipped count, upload count, reaction
   count, broken reply count, and linked Telegram count.
7. Provide a dry-run/audit mode before cutover.
8. Verify count and relationship integrity before allowing the old Chat
   setting to be retired.

No automatic destructive cleanup is included. The administrator may disable
Discourse Chat only after the audit passes and live bridge verification is
complete.

## Removal of Runtime Chat Dependencies

- Remove Chat event hooks for message create/edit/trash.
- Remove the `Chat::MessageReactor` prepend.
- Remove Guardian creation locks and `Chat::Channel` threading patches.
- Remove Chat membership callbacks and scheduled enrollment jobs.
- Remove header Chat-button interception and `/chat` redirects.
- Remove Chat composer button registration and Chat DOM observers.
- Remove the requirement for `disteleplus_chat_channel_id` during normal
  operation. Retain it temporarily as the legacy-import source setting.
- Update Telegram status/setup output to describe the native conversation.
- Ensure plugin boot, webhook processing, UI, and tests work with Chat disabled.

## Compatibility and Rollback

- The schema migration is additive.
- Existing Chat records are never deleted.
- Existing `chat_message_id` values remain available during the compatibility
  period.
- The importer is resumable and idempotent.
- A failed native cutover can be rolled back by deploying the prior plugin
  version and re-enabling Chat; Telegram link rows retain their old IDs.
- Do not remove legacy columns in the same release that performs the cutover.

## Test Plan

### Models and services

- Validation, associations, reply integrity, soft deletion, reaction
  uniqueness, monotonic read cursor, and upload ownership.
- Idempotent create/import behavior and after-commit event/job behavior.

### Request security

- Anonymous denial.
- Unauthorized-group denial.
- Authorized access.
- Staff moderation.
- No cross-user edit/delete.
- Private MessageBus scope.
- Rate limits and malformed input.
- Pagination boundaries.

### Telegram

- Both directions for text, media, voice, replies, edits, deletes, polls, and
  reactions.
- Echo suppression and webhook retry deduplication.
- Telegram topic routing and rate-limit retry behavior.

### Frontend/system

- Shortcut navigation and unread badge.
- Initial load and upward pagination.
- Realtime updates across two sessions.
- Scroll anchoring/new-message indicator.
- Composer text, uploads, reply, edit, delete, reactions, and voice notes.
- Mobile and desktop layouts.
- Accessibility labels and keyboard behavior.

### Independence gate

- Plugin boots with Discourse Chat disabled.
- No runtime reference to `Chat::*`, `/chat/api`, Chat plugin API extensions,
  Chat routes, or Chat DOM selectors outside the optional legacy importer.
- Full Telegram bridge smoke test passes with Chat disabled.

## Implementation Sequence

1. Inventory current Disteleplus integration points and freeze expected
   behavior in tests.
2. Add additive schema migrations and native models.
3. Add Guardian predicates, message service, serializer, notifier, MessageBus
   publisher, unread service, and API controllers.
4. Rewire Telegram inbound and outbound to native message IDs.
5. Build native route, application service, timeline, composer, media,
   reaction, voice-note, and shortcut components.
6. Add the resumable legacy Chat importer and audit endpoint.
7. Remove active Chat hooks, patches, membership jobs, and client integration.
8. Update settings, locales, README, and administrator setup instructions.
9. Add/replace unit, request, job, migration, and system tests.
10. Run Ruby syntax, YAML parsing, JavaScript/Glimmer lint, style lint, type
    checks, request/unit tests, and `git diff --check`.

## Completion Criteria

The work is complete when:

- Disteleplus persists and renders its own conversation.
- Telegram bridging works in both directions using native message IDs.
- Replies, edits, deletes, uploads, reactions, polls, and voice notes work.
- Authorized users receive realtime updates and accurate unread badges.
- Notifications no longer use Chat memberships.
- The old channel can be imported and audited without data loss.
- The plugin boots and operates with Discourse Chat disabled.
- No active frontend or backend code depends on Discourse Chat, apart from the
  isolated administrator-only legacy importer.
- Available automated verification passes and any unavailable environment
  checks are documented.
