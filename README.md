# Jtech

One combined Discourse plugin. Bundles seven previously-separate plugins under a single registration and a single master site setting (`jtech_enabled`). Each sub-plugin keeps its own settings, locales, and Ruby namespace.

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
| Meh (repaint 🤷 `man_shrugging` with a custom glyph) | — | `meh_*` | `meh_enabled` |

The bundle is gated by `jtech_enabled`; each sub-plugin is independently gated by its own setting above.

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

### Meh — replacing emoji with your own images

There is **no bespoke admin page** for this on purpose — Discourse's native emoji system already does the work, and `buildEmojiUrl` checks custom emoji **before** the built-in set, so a custom emoji whose name matches a built-in **overrides** it everywhere it renders (the reaction picker, reaction pills, and `:name:` in posts).

**To replace any emoji** (no plugin change, no rebuild):

1. **Admin → Customize → Emoji → Add new emoji.**
2. Upload your image and **name it exactly after the emoji you want to override** — e.g. `man_shrugging`, `+1`, `joy`, `ok_hand`.
3. Save. It now renders in place of the original.

**Image spec:** square, **transparent PNG**, **72×72 or larger** (144×144 recommended — Discourse scales it down; bigger source = crisper on hi-dpi). Non-square images get distorted.

**Dumbcourse** renders reactions as native Unicode characters, so it can't pick up an emoji image on its own. The plugin bridges this: `app/controllers/discourse_dumbcourse/app_controller.rb` injects every custom-emoji override (`{name → url}`, from `Emoji.custom`) into `window.DUMBCOURSE_SETTINGS.customEmojis`, and `public/dumbcourse.js`'s `reactionGlyph()` renders an `<img>` for any reaction whose name has an override. This **auto-syncs** — whatever you upload natively shows in dumbcourse too, no code change.

The bundled **`meh_enabled`** setting is just a convenience default: it ships `public/images/meh.png` and registers it as `man_shrugging` (the "don't know" shrug → MEH) so the replacement works out of the box without a manual upload. Turn it off to restore the normal shrug, or upload your own `man_shrugging` natively to override the bundled one.

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
