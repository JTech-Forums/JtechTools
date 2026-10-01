# How the JTech theme is built

The theme is an ordinary Discourse theme in [`themes/jtech/`](../../themes/jtech/). Core's theme pipeline compiles it, the same as a theme installed from Git, so its frontend is `.gjs` and plain `.js` like other themes rather than the plugin's TypeScript, and it isn't part of `pnpm lint` or `lint:types`. Admin-facing notes: [features/jtech-theme.md](../features/jtech-theme.md).

## How it gets installed

[`sub_plugins/jtech_theme.rb`](../../sub_plugins/jtech_theme.rb) registers [`db/fixtures/jtech_theme.rb`](../../db/fixtures/jtech_theme.rb), which runs on every `db:migrate` and calls [`DiscourseJtechTheme::Installer.sync!`](../../lib/discourse_jtech_theme/installer.rb):

- It imports `themes/jtech` with `RemoteTheme.import_theme_from_directory`, as core does for its own themes in `db/fixtures/600_themes.rb`. The import works on a copy, so the plugin's files are never touched.
- The theme id and a SHA-256 of the theme's files are kept in `PluginStore` (`jtech-theme` / `bundled_theme`). Nothing is re-imported unless the files changed.
- Updates go into the same theme, so the admin's default/user-selectable choice, components and theme settings survive.
- If the theme was deleted it isn't recreated; `rake jtech:theme:install` (`reinstall!`) brings it back.
- It never raises: a failed import is logged and the migration carries on.
- It skips test databases unless `JTECH_THEME_SEED` is set, so CI's `db:migrate` doesn't compile the theme. The spec calls it directly.
- `JTECH_THEME_DIR` points it at another copy of the theme (used to try it against a running forum).
- Switches: `jtech_enabled` and `jtech_theme_install` (`DiscourseJtechTheme.enabled?`).

## Working on the theme

Sync your edits to a local development forum without a rebuild. Both scripts refuse anything that isn't `localhost`:

```bash
export JTECH_THEME_URL=http://localhost:3000        # your local forum
export JTECH_THEME_API_KEY_FILE=~/path/to/admin-api-key
scripts/theme/watch.sh       # live sync on save (discourse_theme CLI)
ruby scripts/theme/upload.rb # one-shot sync
```

The first run asks which theme to update: pick the JTech the plugin installed, otherwise you get a second copy. The next rebuild re-imports `themes/jtech`, so commit what you want to keep.

## Before updating Discourse

Move a local forum to the new Discourse version, then:

```bash
JT_PW=<admin password> node scripts/theme/check.mjs
```

It must print `all checks passed`. It checks that every core module the theme imports still exists, sweeps the main pages for errors and deprecations caused by the theme, and checks that the hero, cards, footer and reading progress render.

## Where things are

Paths are inside `themes/jtech/`; JavaScript is under `javascripts/discourse/`.

| | |
|---|---|
| `about.json` | palettes **JTech Light** / **JTech Dark** (incl. full Geist gray ramps), `only_theme_color_schemes`, theme site settings |
| `common/color_definitions.scss` | per-mode tokens (`--jt-*`): borders, surfaces, text, shadows |
| `stylesheets/jt-tokens.scss` | maps tokens onto core's `--d-*` / `--token-*` hooks |
| `stylesheets/jt-*.scss` | header, logo, topic list, posts, panels, component restyles, monochrome switches |
| `stylesheets/jt-legacy-content.scss` | post wrappers (`ghbtn`, `logos`) ported from prod's Default theme |
| `components/jt-topic-card.gjs` + `api-initializers/jt-topic-cards.gjs` | discovery lists as cards (`stylesheets/jt-cards.scss`) |
| `components/jt-hero.gjs` (outlet `discovery-list-controls-above`) | front-page hero: headline, search, quick links (`jt-hero.scss`) |
| `stylesheets/jt-post-chrome.scss` | author block, post menu, reactions, solved answer, topic events |
| `components/jt-quick-look.gjs` | Quick look dialog from topic cards (first post via `/posts/by_number`, decorated) |
| `components/jt-context-banner.gjs` (outlet `discovery-list-controls-above`) | category / tag banner (`jt-banner.scss`) |
| `components/jt-footer.gjs` (outlet `below-footer`) | footer columns from `footer_links` (`jt-footer.scss`) |
| `components/jt-reading-progress.gjs` (outlet `topic-above-post-stream`) | reading progress hairline (core `topic:current-post-scrolled`) |
| `components/jt-command-menu.gjs` + `api-initializers/jt-command-menu.js` | ⌘K / Ctrl+K command menu (`jt-cmdk.scss`); opened from the header's search field too |
| `stylesheets/jt-sidebar.scss` | sidebar: tokens, rows, headers, scroll fades, footer |
| `api-initializers/jt-header-actions.gjs` + `components/jt-header-search.gjs`, `jt-header-icon.gjs`, `jt-header-new-topic.gjs` | header right: search field (opens ⌘K) · home · messages · notifications · light/dark · new topic · avatar |
| `components/jt-back-to-top.gjs` (outlet `above-site-header`) | back-to-top button on long non-topic pages |
| `api-initializers/jt-code-blocks.js` | language header on code blocks whose author named one |
| `connectors/category-title-before/jt-category-icon.gjs` | category icon / emoji / square in the Category Boxes tiles (in-element into the tile) |
| `api-initializers/jt-sidebar-docked.js` | no ☰ where the sidebar docks (`jt-header.scss`); clears a remembered "sidebar hidden" |
| `components/jt-scrollbar.gjs` (outlet `above-site-header`) + `jt-base.scss` | overlay page scrollbar on mouse/trackpad devices; thin hover-only scrollbars in panels |
| `stylesheets/jt-profile.scss` | user profiles: header card (every /u/* tab), meta strip, summary stat tiles and section cards |
| `stylesheets/jt-directory.scss` | users directory (/u): period title, toolbar, table card |
| `api-initializers/jt-notice-dismiss.js` | × on core's site notices (7 days / until the text changes; critical notices excluded) |
| `api-initializers/jt-external-links.js` | ↗ on outbound links in posts (`decorateCookedElement`) |
| `stylesheets/jt-leaderboard.scss`, `jt-components.scss` | restyles for gamification, Gated Topics, Category Boxes, admin |
| `stylesheets/jt-type.scss` | type scale (15px root, Geist steps, tracking by size, tabular numerals) |
| `stylesheets/jt-shape.scss` | `corner_style` radii (squircles via `corner-shape`), fading dividers, glass header, press motion |
| `settings.yml` | `corner_style` (squircle/sharp/soft/round), `topic_cards`, `hero_*` (incl. `hero_links` list), `quick_look`, `category_banners`, `tag_banners`, `footer_*`, `reading_progress`, `external_link_icon`, `internal_hosts`, `command_menu`, `card_thumbnails`, `code_language_labels`, `back_to_top`, `overlay_scrollbar`, `header_home_url`, `monochrome_categories`, `monochrome_letter_avatars`, `monochrome_heatmap` |
