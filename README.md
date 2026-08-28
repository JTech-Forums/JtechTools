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
| Translator-tweaks | *(patches `DiscourseTranslator`)* | *(none — gated by translator's own settings)* | `translator_enabled` (upstream) |
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

### Disteleplus — Telegram ⇄ Discourse Chat bridge

Bridges exactly **one Telegram group** with exactly **one Discourse Chat channel**, two-way, so an admin without Telegram can participate in the team's Telegram group from a chat channel (and everyone on Telegram sees their messages). Requires the official `chat` plugin to be enabled; everything no-ops gracefully when it isn't.

**What bridges, and how far** (Bot API limits are real — the bridge documents them instead of faking around them):

- **Text, both ways.** Telegram messages post into the channel **as the matching Discourse user** when the Telegram username matches a Discourse username (the manual `disteleplus_user_mappings` setting, `tg_name:discourse_name` pairs, takes precedence); unmatched senders post via the bridge-bot user with a `**Name (TG):**` prefix. Discourse messages appear in Telegram from the bot, prefixed **username:** — bots cannot impersonate people.
- **Media, both ways,** up to `disteleplus_max_upload_mb` (hard ceiling 20 MB — the Bot API refuses larger bot downloads; bot sends cap at 50 MB). Oversized media becomes a placeholder (inbound) or a forum link (outbound; login-gated if secure uploads are on). Voice messages come in as `.ogg` uploads — add `ogg` to `authorized_extensions`. Animated stickers degrade to `[sticker 😀]` text.
- **Edits, both ways** — with one asymmetry: a Discourse-side edit of a Telegram-originated message stays local (bots cannot edit other people's Telegram messages).
- **Deletes, Discourse → Telegram only.** Telegram never notifies bots about deletions, so Telegram-side deletions leave the Discourse copy in place — that's a Bot API fact, not a setting.
- **Replies, both ways,** threaded via the message-link table.
- **Reactions, both ways, asymmetric.** Telegram reactions land per-user on the chat message (as the matched user, else the bot). Discourse reactions collapse to the bot's single allowed Telegram reaction (most recent wins) from Telegram's fixed emoji set. Requires the bot to be a **group admin** or Telegram never delivers reaction updates.
- **Telegram polls → markdown snapshot** in chat, vote counts refreshed best-effort. No voting from Discourse (chat has no polls).
- **Not bridged:** pins, typing indicators, join/leave notices, and muting (a Telegram mute is a moderation action; a Discourse channel mute is a private notification preference — semantically unrelated).

**Chat lock (optional, `disteleplus_lock_chat_ui`):** the chat button opens the bridge channel directly and creating channels/DMs is hidden client-side and refused server-side (Guardian) — chat becomes this one admin conversation. `disteleplus_lock_chat_exempt_admins` (default on) keeps the full UI for admins.

**Setup (once, ~5 minutes):**

1. **BotFather:** `/newbot` → copy the token. Then `/setprivacy` → **Disable** — *mandatory*, otherwise the bot cannot see ordinary group messages (this is the #1 troubleshooting item).
2. **Telegram group:** add the bot, promote it to **admin** (delete-messages right for delete bridging; admin status is also required for reaction updates). Get the group's chat id (a negative number like `-1001234…`): send any group message, then open `https://api.telegram.org/bot<token>/getUpdates` in a browser — or add @RawDataBot briefly.
3. **Discourse (Admin → Settings → Jtech — Disteleplus):** paste `disteleplus_bot_token`, set `disteleplus_telegram_chat_id`, set `disteleplus_chat_channel_id` (the number in the channel URL, `/chat/c/-/<id>`), adjust mappings/toggles if wanted.
4. Turn on `disteleplus_enabled`, then flip `disteleplus_register_webhook_now` — it auto-generates the webhook secret, calls `setWebhook`, and resets itself. Check `/logs` for a `[jtech-tools disteleplus]` warning if anything failed.
5. Send a message in Telegram → it appears in the channel; reply in the channel → it appears in Telegram.

**Honest limitations** (also inline in the settings descriptions): Telegram username changes silently break the automatic match (fix with a mapping entry); anyone controlling a mapped Telegram account posts as that Discourse user — map people you trust; the bot's messages older than 48 h can't be deleted from Telegram; a group→supergroup migration changes the chat id (update the setting); formatting is flattened to plain text in both directions in v1.

Internals: webhook receiver at `/jtech-disteleplus/telegram/webhook` (secret-header auth, enqueue-and-200), Sidekiq jobs for both directions, echo suppression via a thread-local flag + the `disteleplus_message_links` table, and every chat-plugin API touchpoint isolated in `lib/discourse_disteleplus/chat_adapter.rb`.

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

The merged `config/settings.yml` exposes one admin tab per sub-plugin: **Jtech**, **Jtech — Dislike**, **Jtech — Alternate SMTP**, **Jtech — Mini-mod**, **Jtech — Mod**, **Jtech — Dumbcourse**, **Jtech — Smart search**. TL4 settings remain in Discourse's core **Trust Level 4** tab.

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
