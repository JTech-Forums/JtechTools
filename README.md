# Jtech

One combined Discourse plugin. Bundles previously-separate plugins under a single registration and a single master site setting (`jtech_enabled`). Each sub-plugin keeps its own settings, locales, and Ruby namespace.

## Bundled sub-plugins

| Sub-plugin | Ruby namespace | Settings prefix | Master switch |
| --- | --- | --- | --- |
| Dislike (phantom reactions) | `DiscourseNoLikes` | `dislike_*`, `discourse_no_likes_*`, `no_reactions_*`, `purge_phantom_likes_now` | `discourse_no_likes_enabled` |
| Another SMTP | — | `discourse_another_email_*` | `discourse_another_email_enabled` |
| Mini-mod | `DiscourseMiniMod` | `mini_mod_*`, `tl4_*` | `mini_mod_enabled` |
| Mod-categories | `DiscourseModCategories` | `mod_*`, `precheck_*`, `topic_footer_*`, `topic_reply_prompt_*` | `mod_categories_enabled` |
| Dumbcourse | `DiscourseDumbcourse` | `dumbcourse_*` | `dumbcourse_enabled` |
| Translator-tweaks | *(patches `DiscourseTranslator`)* | `translator_tweaks_*` | `translator_tweaks_enabled` + `translator_enabled` (upstream) |
| Smart search | `DiscourseSmartSearch` | `smart_search_*` | `smart_search_enabled` |
| Desktop pop-ups | `DiscoursePopupNotifications` | `popup_notifications_*` | `popup_notifications_enabled` |
| Disteleplus (Telegram ⇄ chat bridge) | `DiscourseDisteleplus` | `disteleplus_*` | `disteleplus_enabled` |

The bundle is gated by `jtech_enabled`; each sub-plugin is independently gated by its own setting above.

### Desktop pop-up notifications

A Jelly-style toast card that appears in the top-right corner (just below the header search) when a new notification arrives, modelled on the [Jelly](https://github.com/lubabs770/Jelly) macOS notifier's look and delivery.

- **Purely additive.** It subscribes to the same `/notification/:user_id` MessageBus channel that already drives the bell counter and the notifications dropdown, and does nothing else — the bell, the dropdown, and read-state are untouched. Turning it off simply stops the card from appearing.
- **Desktop only.** Never mounts on mobile (`site.mobileView`).
- **Opt-in per user, off by default.** Each user turns it on via a **Desktop Pop Up Notifications** On/Off dropdown on their account page (`/u/:username/preferences/account`), stored in the `jtech_popup_notifications_enabled` user custom field. `popup_notifications_default_enabled` (default `false`) controls the default for users who haven't chosen.
- **Card layout:** the acting user's name on top, their avatar on the left, the topic title in bold, then a short preview of their message (fetched from the source post).
- **Interaction:** clicking the card routes to the post (same as clicking the row in the dropdown); clicking anywhere else — or waiting `popup_notifications_timeout_seconds` (default 20) — dismisses it.

| Setting | Default | Purpose |
| --- | --- | --- |
| `popup_notifications_enabled` | `true` | Master switch. Off ⇒ no card for anyone, per-user preference hidden. |
| `popup_notifications_default_enabled` | `false` | Default for users who haven't set the account-page preference. |
| `popup_notifications_timeout_seconds` | `20` | Seconds the card stays before auto-dismissing. |

### Mod-categories — staff-event notifications

Mod-categories ships a notification fan-out for five staff-event streams in addition to its original topic-level moderator notes. Whenever a moderator performs one of the actions below, every OTHER staff member gets a high-priority bell notification + live MessageBus pop-up alert, AND the event surfaces in the shield-tab user menu alongside topic notes.

| Stream | Event hook | URL on click |
| --- | --- | --- |
| Post deleted by staff | `on(:post_destroyed)` (skips self-deletes + system user) | topic + post number |
| Queued post approved | `on(:reviewable_transitioned_to)` (status=:approved, ReviewableQueuedPost) | `/review/:id` |
| Queued post rejected | `on(:reviewable_transitioned_to)` (status=:rejected, ReviewableQueuedPost) | `/review/:id` |
| User note added | wraps `::DiscourseUserNotes.add_note` (bundled plugin fires no DiscourseEvent) | `/u/:username/notes` |
| Flag note added on a reviewable | `::ReviewableNote.after_create` callback | `/review/:id` |

All five are gated by independent site settings (`mod_notify_staff_on_post_actions`, `mod_notify_staff_on_user_notes`, `mod_notify_staff_on_flag_notes`) so streams can be disabled individually. The fan-out itself lives in `lib/discourse_mod_categories/staff_notifier.rb` and is wrapped in two layers of `rescue StandardError` so a notifier failure can never 500 the underlying moderator action. A 30-second per-user dedup check in `StaffNotifier.recent_duplicate?` protects against an event hook firing twice in quick succession.

The shield-tab `/discourse-mod-categories/notes-feed` returns a UNION of topic-attached notes (legacy behavior — what `TopicCustomField` writes surface as) plus the non-topic event notifications above, so the tab mirrors what the bell shows for every mod-note-kind notification.

### Smart search

Synonym query expansion using **WordNet** (~117K-word English lexical DB, bundled via the `rwordnet` gem) for general English, with a small **tech-jargon YAML overlay** (~70 entries in `config/dictionaries/smart_search_synonyms.yml`) for the abbreviations and brand names WordNet doesn't know (`js ↔ javascript`, `k8s ↔ kubernetes`, `pg ↔ postgres`, etc.). When `smart_search_enabled` is on:

1. The user's original search runs first via Discourse's vanilla `Search#execute`.
2. If the original returns fewer than `smart_search_minimum_results` posts (default 5), up to `smart_search_variant_limit` (default 2, max 5) synonym-substituted variant searches run and their results are merged in.
3. Every smart-search path (dictionary load, variant generation, inner variant search, merge) is wrapped in `rescue StandardError` → log and return the vanilla result. The fallback contract is documented at the top of `lib/discourse_smart_search/search_extension.rb`.

No external services, no API keys, no embedding models — both backends (WordNet via SQLite DB shipped in-gem, plus the YAML overlay) run in-process. This is deliberate: the previous semantic-search attempt (Discourse AI embeddings) was disabled after every query started returning 500 when the embedding backend went down. Smart search's failure mode is "results identical to vanilla," never "search broken."

Editing the overlay: only ADD entries WordNet doesn't already cover — abbreviations, brand names, protocol initialisms. Don't curate general English (WordNet handles it for free). Lowercase ASCII rows, each row is a symmetric synonym group. Reloaded at boot (or via `DiscourseSmartSearch::Synonyms.reload!` in a Rails console). See `docs/smart_search.md` for the full architecture: two-backend lookup order, request-flow diagram, fallback contract, performance notes, and a console-recipe for diagnostics.

### Custom emoji as reactions (and in dumbcourse)

Replacing emoji and choosing reactions is **entirely native** — the plugin ships **no bundled images and no emoji settings**. Its only job here is bridging the dumbcourse SPA, which otherwise can't see Discourse's emoji system.

**Replace any emoji** (no plugin change, no rebuild): **Admin → Customize → Emoji → Add new emoji**, upload your image, and **name it after the emoji you want to override** (e.g. `man_shrugging`, `+1`, `joy`). `buildEmojiUrl` checks custom emoji **before** the built-in set, so it overrides everywhere it renders.

**Set a reaction from an uploaded emoji:** the `discourse_reactions_enabled_reactions` setting (Admin → Settings → **Emoji** area) is an emoji **picker** that already includes your uploaded custom emoji — add it there.

**Image spec:** square, **transparent PNG**, **72×72 or larger** (144×144 recommended — Discourse scales it down; bigger source = crisper). Non-square images get distorted.

**Dumbcourse bridge** (the only plugin code involved) — `app/controllers/discourse_dumbcourse/app_controller.rb` injects into `window.DUMBCOURSE_SETTINGS`:

- `enabledReactions` — the forum's actual `discourse_reactions_enabled_reactions`, so the SPA's reaction picker matches the main forum instead of a hardcoded list (this also fixes the old `laughing`/`joy` drift).
- `customEmojis` — `{name → url}` from `Emoji.custom`, every native upload + plugin-registered emoji.

`public/dumbcourse.js` then builds its reaction list from `enabledReactions` (falling back to the old hardcoded set), and `reactionGlyph()` renders each reaction as: a custom-emoji `<img>` if one exists, else the unicode glyph (via the bundled `emoji_map.json` codepoints), else the raw name. So **anything you enable/upload natively shows in dumbcourse automatically — no code change, no rebuild beyond shipping this bridge once.**

### Moderator powers — one toggle per grant

Every right the mini-mod and mod-categories modules hand to moderators (or TL4 users) is individually gated by its own site setting, organized into per-feature admin tabs: **Jtech — Mod** (master + moderator category create/edit/delete), **Mod: Whispers**, **Mod: Notes**, **Mod: Staff notifications**, **Mod: Topic tools**, and **Mod: Checklists**. All toggles default to the previously shipped behavior, so upgrading changes nothing until you flip switches — with three deliberate security exceptions:

- **Badge-member enumeration is staff-only.** `/discourse-mod-categories/badge-members/:id` (the PM "Add badge group" lookup) previously let *any* PM-capable user list every holder of any badge; it now requires moderator rights, and the composer button only renders for staff.
- **Note entries belong to their author.** Editing/deleting another staff member's private-note or note reply now requires being an admin or the site opting in via `mod_moderators_can_edit_others_notes` (default off).
- **Targeted checklists can't gate admins.** A moderator-authored targeted checklist previously overrode staff status entirely and could block an admin from posting; admins are now always exempt.

Serializer exposures (footer texts, pinned-post HTML, reply-approval flags, note bodies, whisper participant lists, unread counters) also now respect the module master switch and their feature toggles instead of leaking whenever the plugin bundle was enabled.

### Disteleplus — Telegram ⇄ Discourse Chat bridge

Bridges exactly **one Telegram group** with exactly **one Discourse Chat channel**, two-way, so an admin without Telegram can participate in the team's Telegram group from a chat channel (and everyone on Telegram sees their messages). Requires the official `chat` plugin to be enabled; everything no-ops gracefully when it isn't.

**What bridges, and how far** (Bot API limits are real — the bridge documents them instead of faking around them):

- **Text, both ways.** Telegram messages post into the channel **as the matching Discourse user** when the Telegram username matches a Discourse username (the `disteleplus_user_map` table setting — edited via a proper row editor in admin — takes precedence; the legacy pipe-delimited `disteleplus_user_mappings` value is migrated automatically); unmatched senders post via the bridge-bot user with a `**Name (TG):**` prefix. Discourse messages appear in Telegram from the bot, prefixed **username:** — bots cannot impersonate people.
- **Media, both ways,** up to `disteleplus_max_upload_mb` (hard ceiling 20 MB — the Bot API refuses larger bot downloads; bot sends cap at 50 MB). Oversized media becomes a placeholder (inbound) or a forum link (outbound; login-gated if secure uploads are on). Voice messages come in as `voice-note-*.ogg` uploads and get the voice-note player (see below). Animated stickers degrade to `[sticker 😀]` text.
- **Edits, both ways** — with one asymmetry: a Discourse-side edit of a Telegram-originated message stays local (bots cannot edit other people's Telegram messages).
- **Deletes, Discourse → Telegram only.** Telegram never notifies bots about deletions, so Telegram-side deletions leave the Discourse copy in place — that's a Bot API fact, not a setting.
- **Replies, both ways,** threaded via the message-link table.
- **Reactions, both ways, asymmetric.** Telegram reactions land per-user on the chat message (as the matched user, else the bot). Discourse reactions collapse to the bot's single allowed Telegram reaction (most recent wins) from Telegram's fixed emoji set. Requires the bot to be a **group admin** or Telegram never delivers reaction updates.
- **Telegram polls → markdown snapshot** in chat, vote counts refreshed best-effort. No voting from Discourse (chat has no polls).
- **Not bridged:** pins, typing indicators, join/leave notices, and muting (a Telegram mute is a moderation action; a Discourse channel mute is a private notification preference — semantically unrelated).

**Chat lock (optional, `disteleplus_lock_chat_ui`):** the header chat button opens the bridged conversation directly (not the drawer/index), all chat hub routes redirect there, and creating channels, DMs **and threads** is hidden client-side and refused server-side — for **everyone, admins included**; there is no creation exemption (turn the lock off to create something, then back on). Enforcement is a Guardian prepend for channels/DMs and a `Chat::Channel#threading_enabled` prepend for threads, so the block holds against the API, not just the UI. `disteleplus_lock_chat_exempt_admins` (default on) only lets admins still *browse* the hub pages instead of being redirected.

**Forced channel notifications (`disteleplus_force_channel_notifications`, default on):** every user allowed into chat is enrolled in the bridge channel at notification level **always** (desktop + web push), chat is re-enabled for anyone who had switched it off, and the level is pinned — a `before_save` on the membership snaps changes back, a scheduled sync runs every 30 minutes, and new/approved/group-added users are enrolled within seconds. `/disteleplus_sync_notifications` (Telegram) or `disteleplus_notification_sync_now` (admin) forces a run; `/disteleplus_status` reports how many members are at "always" and whether site-wide push is on. This deliberately overrides personal mute choices for this one channel. Web push additionally needs core's `push_notifications_enabled` and each person to have accepted push on a device — the plugin cannot do that for them, and the sync log counts members without a push subscription.

**Voice notes (`disteleplus_voice_notes_enabled`, default on):** a microphone button in the chat composer (bridge channel only by default) records in-browser with a live level meter and a countdown to `disteleplus_voice_note_max_seconds`, previews, and sends the note as its own message. Every audio in chat gets a compact waveform player (play, click/drag scrub, elapsed/total, 1×/1.5×/2× speed remembered per browser, download) instead of the browser default; `disteleplus_voice_player_all_audio` limits it to voice notes only. Voice notes travel to Telegram as real **voice bubbles** (`sendVoice`) — Firefox records OGG/OPUS natively; Chrome/Edge WebM is transcoded server-side when `ffmpeg` is present (it is in the standard Discourse image), otherwise the note arrives as an audio file. Telegram voice messages arrive as `voice-note-<n>s.ogg` and get the same player. The recorder uploads through core, so enabling the feature adds `ogg|webm|m4a|opus` to `authorized_extensions` if missing.

**Setup (once, ~5 minutes):**

1. **BotFather:** `/newbot` → copy the token. Then `/setprivacy` → **Disable** — *mandatory*, otherwise the bot cannot see ordinary group messages (this is the #1 troubleshooting item).
2. **Telegram group:** add the bot and promote it to **admin**. Grant manage-topics if the bot should create the Uploads topic, delete-messages for delete bridging, and keep admin status for reaction updates.
3. **Discourse (Admin → Settings → Jtech — Disteleplus):** paste `disteleplus_bot_token`, set `disteleplus_chat_channel_id` (the number in `/chat/c/-/<id>`), and turn on `disteleplus_enabled`.
4. Flip `disteleplus_register_webhook_now` — it generates the webhook secret, calls `setWebhook`, installs an admin-only Telegram command menu, and resets itself. Check `/logs` for warnings.
5. In the Telegram group, run `/disteleplus_setup`. Bind General, then either enter an existing upload topic and run `/disteleplus_bind_uploads`, or run `/disteleplus_create_uploads Uploads` from General. The bot reads and saves the group/thread IDs automatically.
6. Run `/disteleplus_status`, then send a normal message in Telegram and reply from Discourse Chat to test both directions.

**Honest limitations** (also inline in the settings descriptions): Telegram username changes silently break the automatic match (fix with a mapping entry); anyone controlling a mapped Telegram account posts as that Discourse user — map people you trust; the bot's messages older than 48 h can't be deleted from Telegram; a group→supergroup migration changes the chat id (update the setting); formatting is flattened to plain text in both directions in v1.

Internals: webhook receiver at `/jtech-disteleplus/telegram/webhook` (secret-header auth, enqueue-and-200), Sidekiq jobs for both directions, echo suppression via a thread-local flag + the `disteleplus_message_links` table, and every chat-plugin API touchpoint isolated in `lib/discourse_disteleplus/chat_adapter.rb`.

#### Forum upload archive topic

Disteleplus can additionally mirror attachments from ordinary forum posts into
a dedicated Telegram Forum Topic. This is a one-way secondary copy: JTech
remains the source of truth and its Upload is never moved or deleted. Each
Telegram file has a compact caption whose collapsed expandable section contains
the post comment, author, UTC time, exact/human file size, topic title, and a
link back to the exact post. Searchable tags (`#jtechupload`, file type,
category, and a short `#jtu_…` fingerprint) make Telegram lookup practical;
the full Discourse SHA-1 is included in the expanded metadata.

**No-ID Telegram setup:** after the webhook is registered, Telegram group
administrators get these commands in the bot command menu:

- `/disteleplus_setup` — a short guided checklist.
- `/disteleplus_bind_general` — run in General; saves the group and keeps the
  existing Chat bridge in General.
- `/disteleplus_bind_uploads [name]` — run inside an existing destination
  topic; saves that thread as the upload archive.
- `/disteleplus_create_uploads [name]` — run in General; creates and binds the
  topic (the bot needs manage-topics permission).
- `/disteleplus_status` — confirms the human topic name, saved destination,
  whether the live mirror is enabled, the chat lock state, channel
  notification enrolment counts, and voice-note capability.
- `/disteleplus_sync_notifications` — re-enrols every eligible Discourse
  member in the bridge channel at notification level "always".

Every setup command verifies the sender through Telegram's `getChatMember` and
accepts only a group creator/administrator. Commands are consumed before the
Chat bridge, so neither successful nor rejected setup attempts appear in
Discourse. Binding a destination never starts the historical archive: measure
and start it explicitly in Discourse admin settings.

The live path observes both new and edited posts. The historical path walks
`UploadReference` rows in small ascending-ID batches and records each delivered
`(post_id, upload_id)` occurrence in `disteleplus_forum_upload_links`, making a
repeat run resumable. The receipt snapshots and indexes the upload SHA-1, so a
delivery can still be found by hash if its forum association later changes.
Telegram rate limits re-enqueue only the affected file.
Files above the separately configurable outbound limit (maximum 50 MB) remain
on JTech and produce a linked metadata message instead.

Safety defaults exclude private messages, whispers, deleted/hidden posts and
read-restricted categories. A category allowlist can narrow the archive;
restricted categories require a separate explicit switch. Before sending,
`disteleplus_forum_upload_measure_now` logs eligible post/occurrence/unique-file
counts, total bytes, date range, extension breakdown, oversize volume and
already-delivered count. `disteleplus_forum_upload_backfill_now` measures, then
starts or resumes the paced archive.

Historical sends are spaced four seconds apart by default (15/minute), below
Telegram's documented 20-messages-per-minute group limit. Batch continuation
waits until the last scheduled delivery in the current batch, so increasing the
batch size does not accidentally increase the send rate. Telegram 429 replies
remain independently retryable as a safety net.

When Telegram topics are in use, set `disteleplus_chat_topic_id` for the
existing two-way Chat bridge and `disteleplus_forum_upload_topic_id` for the
archive. Human messages in the archive topic are explicitly excluded from the
inbound Chat bridge.

## Layout

```
plugin.rb              master plugin file — instance_eval's each file under sub_plugins/
about.json
sub_plugins/
  dislike.rb           body of original Dislike/plugin.rb
  another_smtp.rb      body of original discourse-another-smtp/plugin.rb
  mini_mod.rb          body of original discourse-mini-mod/plugin.rb
  mod_categories.rb    body of original discourse-mod/plugin.rb + staff-event notifications
  dumbcourse.rb        body of original dumbcourse/plugin.rb
  translator_tweaks.rb runtime patches for upstream discourse/discourse-translator
                       (alltechdev's two-commit fork ported as in-process tweaks
                       so we can track upstream and apply our overrides on top)
  smart_search.rb      synonym query expansion (in-process, no external services)
scripts/
  translator_backfill_foreign_detection.rb
                       one-shot rails runner; enqueues the upstream translator's
                       detect job for legacy foreign-script posts
config/
  settings.yml         all settings.yml files merged into seven jtech_* admin tabs
  dictionaries/
    smart_search_synonyms.yml
                       symmetric synonym groups for smart_search; lowercase ASCII
  locales/
    server.en.yml      deep-merged server locale + categories.jtech_* translations
    client.en.yml      deep-merged client locale
lib/
  discourse_no_likes/        from Dislike
  discourse_mini_mod/        from discourse-mini-mod
  discourse_mod_categories/  from discourse-mod + staff_notifier.rb (fan-out helper)
  discourse_dumbcourse/      from dumbcourse
  discourse_smart_search/    synonyms / query_expander / Search prepend module
app/
  controllers/{discourse_mod_categories,discourse_dumbcourse}/
  models/{discourse_no_likes,*_site_setting.rb}
  jobs/regular/
db/migrate/            phantom-reactions table migration from Dislike
assets/                merged JS/CSS — no filename collisions across sources
public/                Dumbcourse SPA bundle (index.html, dumbcourse.{js,css}, emoji_map.json)
```

## Admin-UI tabs

The plugin config page at `/admin/plugins/jtech-tools` renders one tab per sub-plugin — **Dislike**, **Alternate SMTP**, **Mini-mod**, **Mod** (spanning its six settings groups), **Dumbcourse**, **Translator tweaks**, **Smart search**, **Pop-ups**, **Disteleplus** — plus core's **All settings** tab kept last as a search-everything fallback. The same category grouping also appears on the classic Admin → Settings sidebar. The `tl4_*` settings live on the Mini-mod tab (they are implemented by, and inert without, that module).

## Visual review (screenshot specs)

Two GitHub Actions workflows render visual fixtures of the plugin's UI surface:

- `Feature Screenshots` — ~25 hand-picked scenarios capturing the actively-developed features. Runs on push to `main`, PRs, and manual dispatch. Artifact: `feature-screenshots`.
- `Comprehensive Screenshots` — parameterized matrix across kinds × lengths × read-states × roles × ordinals, ~1180 scenarios attempted. **Dispatch-only** (gated by `ENV["JTECH_COMPREHENSIVE_SHOTS"]` so it never slows ordinary CI). Run via:

  ```bash
  gh workflow run "Comprehensive Screenshots" --ref <branch> --repo Shalom-Karr/JtechTools
  ```

  Spec files: `spec/system/comprehensive_screenshots_spec.rb` plus `_part2`, `_part3`, `_part4`. Empirical success rate ~75% across the full matrix (the fast-path P6 section alone hits 100%). Section-prefix convention so the artifact zip sorts navigably: `A1xx` bell rows, `B2xx` shield tab, `C3xx` mod-note panel, `D4xx` bell stacking, `E5xx`/`K1xx` smart search, `G7xx` time-ago variants, `H8xx` density 1→100, etc.

## Why one `enabled_site_setting`?

Discourse plugins can only register a single `enabled_site_setting` at load time. The bundle's master gate is `jtech_enabled`. Every sub-plugin's logic still checks its own master switch internally (Guardian overrides, event hooks, controllers, etc. all early-return when their sub-feature is disabled), so you keep per-feature on/off control through admin settings.

## Installation

```bash
cd /var/discourse/plugins
git clone https://github.com/JTech-Forums/JtechTools.git jtech-tools
cd /var/discourse
./launcher rebuild app
```
