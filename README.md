# Jtech

One combined Discourse plugin. Bundles five previously-separate plugins under a single registration and a single master site setting (`jtech_enabled`). Each sub-plugin keeps its own settings, locales, and Ruby namespace.

## Bundled sub-plugins

| Sub-plugin | Ruby namespace | Settings prefix | Master switch |
| --- | --- | --- | --- |
| Dislike (phantom reactions) | `DiscourseNoLikes` | `dislike_*`, `discourse_no_likes_*`, `no_reactions_*`, `purge_phantom_likes_now` | `discourse_no_likes_enabled` |
| Another SMTP | — | `discourse_another_email_*` | `discourse_another_email_enabled` |
| Mini-mod | `DiscourseMiniMod` | `mini_mod_*`, `tl4_*` | `mini_mod_enabled` |
| Mod-categories | `DiscourseModCategories` | `mod_*`, `precheck_*`, `topic_footer_*`, `topic_reply_prompt_*` | `mod_categories_enabled` |
| Dumbcourse | `DiscourseDumbcourse` | `dumbcourse_*` | `dumbcourse_enabled` |
| Translator-tweaks | *(patches `DiscourseTranslator`)* | *(none — gated by translator's own settings)* | `translator_enabled` (upstream) |

The bundle is gated by `jtech_enabled`; each sub-plugin is independently gated by its own setting above.

## Layout

```
plugin.rb              master plugin file — instance_eval's each file under sub_plugins/
about.json
sub_plugins/
  dislike.rb           body of original Dislike/plugin.rb
  another_smtp.rb      body of original discourse-another-smtp/plugin.rb
  mini_mod.rb          body of original discourse-mini-mod/plugin.rb
  mod_categories.rb    body of original discourse-mod/plugin.rb
  dumbcourse.rb        body of original dumbcourse/plugin.rb
  translator_tweaks.rb runtime patches for upstream discourse/discourse-translator
                       (alltechdev's two-commit fork ported as in-process tweaks
                       so we can track upstream and apply our overrides on top)
scripts/
  translator_backfill_foreign_detection.rb
                       one-shot rails runner; enqueues the upstream translator's
                       detect job for legacy foreign-script posts
config/
  settings.yml         all five settings.yml files merged into six jtech_* admin tabs
  locales/
    server.en.yml      deep-merged server locale + categories.jtech_* translations
    client.en.yml      deep-merged client locale
lib/
  discourse_no_likes/        from Dislike
  discourse_mini_mod/        from discourse-mini-mod
  discourse_mod_categories/  from discourse-mod
  discourse_dumbcourse/      from dumbcourse
app/
  controllers/{discourse_mod_categories,discourse_dumbcourse}/
  models/{discourse_no_likes,*_site_setting.rb}
  jobs/regular/
db/migrate/            phantom-reactions table migration from Dislike
assets/                merged JS/CSS — no filename collisions across sources
public/                Dumbcourse SPA bundle (index.html, dumbcourse.{js,css}, emoji_map.json)
```

## Admin-UI tabs

The merged `config/settings.yml` exposes one admin tab per sub-plugin: **Jtech**, **Jtech — Dislike**, **Jtech — Alternate SMTP**, **Jtech — Mini-mod**, **Jtech — Mod**, **Jtech — Dumbcourse**. TL4 settings remain in Discourse's core **Trust Level 4** tab.

## Why one `enabled_site_setting`?

Discourse plugins can only register a single `enabled_site_setting` at load time. The bundle's master gate is `jtech_enabled`. Every sub-plugin's logic still checks its own master switch internally (Guardian overrides, event hooks, controllers, etc. all early-return when their sub-feature is disabled), so you keep per-feature on/off control through admin settings.

## Installation

```bash
cd /var/discourse/plugins
git clone https://github.com/JTech-Forums/JtechTools.git
cd /var/discourse
./launcher rebuild app
```
