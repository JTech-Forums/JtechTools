# How the JTech theme is built

The theme is an ordinary Discourse theme in [`themes/jtech/`](../../themes/jtech/). Core's theme pipeline compiles it, the same as a theme installed from Git. Its frontend is TypeScript (`.ts`, `.gts`) like the plugin's, which core's pipeline compiles from Discourse 2026.7 on (older forums get a pinned plugin version, see `.discourse-compatibility`). `pnpm lint:types` type-checks it with the plugin, with `virtual:theme` (`settings`, `themePrefix`) typed in `types/jtech-theme.d.ts`; add a setting there when you add one to `settings.yml`. `pnpm lint:theme` (part of `pnpm lint`, and its own CI job) runs ESLint, Prettier and stylelint over it with the plugin's configs. Admin-facing notes: [features/jtech-theme.md](../features/jtech-theme.md).

## Tests

[`spec/system/jtech_theme_spec.rb`](../../spec/system/jtech_theme_spec.rb) installs the theme, makes it the default and walks the main pages (latest, categories, a category, a tag, a topic, users, a profile, search) as a visitor, a member and an admin, on desktop and on a phone. It fails on a theme error, on a page error, on a deprecation (system specs raise on those) and when a JTech surface doesn't render. It also covers the command menu, Quick look, the header's + on a tag page, full-page links, the login gate and dark mode. CI runs it against Discourse `latest`, so it is the first warning that a core update broke the theme. Screenshots land in `tmp/capybara/jtech_theme/`.

## How it gets installed

[`sub_plugins/jtech_theme.rb`](../../sub_plugins/jtech_theme.rb) registers [`db/fixtures/jtech_theme.rb`](../../db/fixtures/jtech_theme.rb), which runs on every `db:migrate` and calls [`DiscourseJtechTheme::Installer.sync!`](../../lib/discourse_jtech_theme/installer.rb):

- It imports `themes/jtech` with `RemoteTheme.import_theme_from_directory`, as core does for its own themes in `db/fixtures/600_themes.rb`. The import works on a copy, so the plugin's files are never touched.
- The theme id and a SHA-256 of the theme's files are kept in `PluginStore` (`jtech-theme` / `bundled_theme`). Nothing is re-imported unless the files changed.
- Updates go into the same theme, so the admin's default/user-selectable choice, components and theme settings survive.
- On the first install it takes over a "JTech" theme someone installed by hand (same name, `about_url` `https://jtechforums.org`, and only one of them) instead of adding a second one. The `about_url` is read from the theme's stored `about.json` (the `about` theme field), because core links a `RemoteTheme` only for Git imports; zip uploads and `discourse_theme` syncs have none. A Git install it takes over is unlinked from its repo, so core's `themes:update` can't pull the old code back over it.
- If the theme was deleted it isn't recreated. Turning `jtech_theme_install` on queues `Jobs::JtechThemeSync` (`restore!`), which brings it back; `rake jtech:theme:install` (`reinstall!`) does too, and re-imports even when nothing changed.
- Anything an admin changes in the theme's files from the admin editor is replaced on the next update; settings, palettes, components and theme site settings are kept (core only creates theme site settings that don't exist yet).
- It never raises: a failed import is logged and the migration carries on.
- It skips test databases unless `JTECH_THEME_SEED` is set, so CI's `db:migrate` doesn't compile the theme. The spec calls it directly.
- `JTECH_THEME_DIR` points it at another copy of the theme (used to try it against a running forum).
- Switches: `jtech_enabled` and `jtech_theme_install` (`DiscourseJtechTheme.enabled?`).

## Working on the theme

Sync your edits to a local development forum without a rebuild. Both scripts refuse anything that isn't `localhost`:

```bash
export JTECH_THEME_URL=http://localhost:3000        # your local forum
export JTECH_THEME_API_KEY_FILE=~/path/to/admin-api-key
ruby scripts/theme/watch.rb  # live sync on save (discourse_theme CLI)
ruby scripts/theme/upload.rb # one-shot sync
```

The first run asks which theme to update: pick the JTech the plugin installed, otherwise you get a second copy. The next rebuild re-imports `themes/jtech`, so commit what you want to keep.

## Before updating Discourse

Move a local forum to the new Discourse version, then:

```bash
JT_PW=<admin password> pnpm theme:check
```

It must print `all checks passed`. `CHROME` points it at the Chromium to drive if Playwright's own isn't in `~/.cache/ms-playwright`. It checks that every core module the theme imports still exists, sweeps the main pages for errors and deprecations caused by the theme, and checks that the hero, cards, footer and reading progress render. The system spec above covers the same ground in CI; this script is for checking against a forum with your real data and components.

## Rules of thumb

- **Same-site links that aren't forum pages** need `data-auto-route="true"`, or core's click handler routes them inside the forum and shows its 404 page. `lib/jt-links.ts` (`needsFullPageLoad`) works that out from the router; use it for any link built from a setting.
- **Don't set tracked state from a modifier** during render (Ember asserts in development, and it costs a second render). Defer it (`schedule("afterRender")`), as `jt-category-icon` does.
- **No `backdrop-filter`, `transform` or `filter` on `.d-header`** itself: it makes the header the containing block for core's fixed menu panels and backdrop. Put effects on a pseudo-element.
- **Gate on core's own flags** (`site.can_search`, `can_send_private_messages`, `can_create_topic`, `site.isReadOnly`, `tagging_enabled`) before showing an entry point, so nothing offers what the visitor can't do.

## Where things are

Paths are inside `themes/jtech/`; the TypeScript is under `javascripts/discourse/`.

| | |
|---|---|
| `about.json` | palettes **JTech Light** / **JTech Dark** / **JTech Dim** (incl. full gray ramps; `common/color_definitions.scss` derives the theme's surfaces and greys from them), `only_theme_color_schemes`, theme site settings |
| `api-initializers/jt-palette-picker.ts` | interface preferences: the dark-palette picker names the theme's default ("JTech Dark") instead of core's "-1" when the theme limits palettes to its own |
| `common/color_definitions.scss` | per-mode tokens (`--jt-*`): borders, surfaces, text, shadows |
| `stylesheets/jt-tokens.scss` | maps tokens onto core's `--d-*` / `--token-*` hooks |
| `stylesheets/jt-notifications.scss` | notifications page (/my/notifications): filters as a toolbar, the list a divided card; the bell's panel: tabs, rows, bottom bar; on both, unread rows tinted with a bold name and the type badge black / white instead of the accent |
| `stylesheets/jt-*.scss` | header, logo, topic list, posts, panels, component restyles, monochrome switches |
| `stylesheets/jt-legacy-content.scss` | post wrappers (`ghbtn`, `logos`) ported from prod's Default theme |
| `stylesheets/jt-static.scss` | the static pages (/guidelines, /faq, /tos, /privacy): a measured reading column at the post's size and leading, headings, lists and links like a post's, the edit link quiet under the nav |
| `components/jt-topic-card.gts` + `api-initializers/jt-topic-cards.gts` | discovery lists as cards (`stylesheets/jt-cards.scss`) |
| `stylesheets/jt-preferences.scss` | preferences (/my/preferences/*): each group a card with its label as title, fields with quiet labels and the theme's controls, help text small, Save Changes on a ruled bar |
| `components/jt-hero.gts` (outlet `discovery-list-controls-above`) | front-page hero: headline, search, quick links (`jt-hero.scss`) |
| `stylesheets/jt-badges.scss` | badges (/badges): display title, group labels, each badge a card with a three-line description; a badge's page: the big card, the people who earned it as cards |
| `stylesheets/jt-post-chrome.scss` | author block, post menu, reactions, solved answer, topic events |
| `stylesheets/jt-topic-footer.scss` | under a topic: the suggested / new & unread list as a divided card (header hidden on phones), "want to read more?" as a sentence; on phones the footer buttons sized alike and Reply keeping its word |
| `components/jt-quick-look.gts` | Quick look dialog from topic cards (first post via `/posts/by_number`, decorated) |
| `components/jt-context-banner.gts` (outlet `discovery-list-controls-above`) | category / tag banner (`jt-banner.scss`) |
| `components/jt-footer.gts` (outlet `below-footer`) | footer columns from `footer_links` (`jt-footer.scss`) |
| `stylesheets/jt-login.scss` | log in / sign up pages (/login, /signup): the form and the other ways in on one card, fields as the theme's controls with core's floating labels placed for them, the footer off these pages |
| `components/jt-reading-progress.gts` (outlet `topic-above-post-stream`) | reading progress hairline (core `topic:current-post-scrolled`) |
| `components/jt-command-menu.gts` + `api-initializers/jt-command-menu.ts` | ⌘K / Ctrl+K command menu (`jt-cmdk.scss`); opened from the header's search field too |
| `lib/jt-shortcuts.ts` + `api-initializers/jt-shortcuts.ts` | the command menu's keyboard shortcuts: core's, and the theme's own `g` keys (bound outside text fields, labelled in core's `?` help by copying the menu's strings under `keyboard_shortcuts_help.jtech`) |
| `stylesheets/jt-sidebar.scss` | sidebar: tokens, rows, headers, scroll fades, footer |
| `stylesheets/jt-groups.scss` | groups (/g): filters as a toolbar, each group a card (name, @mention, member count pill, description, your standing); a group's page: header card, members filter; its members table gets jt-directory's table card |
| `api-initializers/jt-header-actions.gts` + `components/jt-header-search.gts`, `jt-header-icon.gts`, `jt-header-new-topic.gts` | header: search field (opens ⌘K) centred on the bar on wide screens with a mouse (outlet `before-header-panel`), otherwise in the icon row · home · messages · notifications · light/dark · new topic · avatar |
| `api-initializers/jt-avatar-menu.ts` + `lib/jt-user-menu.ts` | the avatar opens core's user menu on the profile tab (review queue while its badge shows), so it doesn't repeat the bell; `pickUserMenuTab` is shared with the bell and envelope |
| `components/jt-back-to-top.gts` (outlet `above-site-header`) | back-to-top button on long non-topic pages |
| `api-initializers/jt-code-blocks.ts` | language header on code blocks whose author named one |
| `connectors/category-title-before/jt-category-icon.gts` | category icon / emoji / square in the Category Boxes tiles (in-element into the tile) |
| `api-initializers/jt-sidebar-docked.ts` | no ☰ where the sidebar docks (`jt-header.scss`); clears a remembered "sidebar hidden" |
| `api-initializers/jt-mobile-logo.ts` | phones: `logo_small` in the header through core's `home-logo-image-url` transformer, unless a `mobile_logo` is uploaded |
| `components/jt-scrollbar.gts` (outlet `above-site-header`) + `jt-base.scss` | overlay page scrollbar on mouse/trackpad devices; thin hover-only scrollbars in panels |
| `lib/jt-icon-map.ts` + `api-initializers/jt-lucide-icons.ts` + `assets/icons-sprite.svg` | Lucide icons (setting `lucide_icons`): the map says which Font Awesome icon becomes which Lucide one (filled for on-states); `pnpm theme:icons` builds the sprite from `lucide-static` and `lint:theme` fails if it's stale; the initializer points icons and core's aliases (`d-liked`, `notification.*`) at it. `LUCIDE-LICENSE.txt` is Lucide's ISC licence |
| `stylesheets/jt-profile.scss` | user profiles: header card (every /u/* tab), meta strip, summary stat tiles and section cards |
| `stylesheets/jt-directory.scss` | users directory (/u): period title, toolbar, table card |
| `stylesheets/jt-search.scss` | full-page search (/search): the field with its glyph, the count as the title with the term in a pill, bulk-select / sort as a toolbar under it, results in one divided card, chips for tags and categories, cards for people, the nothing-found card; lifts core's 10% insets |
| `api-initializers/jt-notice-dismiss.ts` | × on core's site notices (7 days / until the text changes; critical notices excluded) |
| `components/jt-first-reply.gts`, `jt-jump-buttons.gts`, `connectors/user-card-metadata/jt-last-seen.gts`, `api-initializers/jt-post-links.ts`, `stylesheets/jt-extras.scss` | what used to be separate components: first-reply prompt, first/last post buttons, last seen on user cards, full-page links in posts, code line numbers, padlocks, tablet composer, core category boxes |
| `components/jt-gate.gts` (outlet `topic-area-bottom`) | login gate for logged-out visitors on `gated_categories` / `gated_tags`: the post stream is clipped and fades into the card (`jt-gate.scss`) |
| `stylesheets/jt-empty.scss` | core's text-only empty states (no messages / bookmarks / drafts / notifications …) as a centred card with a glyph chip; the 404 page's title, button and search card |
| `stylesheets/jt-topic-list.scss` + `api-initializers/jt-active-tab.ts`, `jt-list-controls.ts` | desktop list controls: one line when it fits, otherwise the filters move up a line and the tabs stay beside the buttons (`--jt-list-buttons` holds the buttons' width); New Topic icon-only below 66rem, tabs scroll sideways with edge fades, current tab scrolled into view |
| `api-initializers/jt-external-links.ts` | ↗ on outbound links in posts (`decorateCookedElement`) |
| `stylesheets/jt-leaderboard.scss`, `jt-components.scss` | restyles for gamification, Gated Topics, Category Boxes, admin |
| `stylesheets/jt-tags.scss` + `api-initializers/jt-tags-page.ts` | tags page (/tags): title row with the admin's create form, sort as pills, each list a wrap of chips (# name, count in a pill); the initializer strips core's "x" from the counts |
| `stylesheets/jt-type.scss` | type scale (core's 16px root, Geist steps, tracking by size, tabular numerals) |
| `stylesheets/jt-about.scss` | about page (/about): display title over the description, stats as tiles, staff as cards, the contact / activity column as one ruled card; lifts core's 1100px cap |
| `stylesheets/jt-shape.scss` | `corner_style` radii (squircles via `corner-shape`), fading dividers, glass header, press motion |
| `settings.yml` | `corner_style` (squircle/sharp/soft/round), `topic_cards`, `hero_*` (incl. `hero_links` list), `quick_look`, `category_banners`, `tag_banners`, `footer_*`, `reading_progress`, `external_link_icon`, `internal_hosts`, `command_menu`, `card_thumbnails`, `code_language_labels`, `back_to_top`, `overlay_scrollbar`, `header_home_url`, `color_mode_toggle`, `code_line_numbers`, `first_reply_prompt*`, `user_card_last_seen`, `topic_jump_buttons`, `hide_lock_icons`, `mobile_small_logo`, `gated_categories`, `gated_tags`, `monochrome_categories`, `monochrome_letter_avatars`, `monochrome_heatmap`, `monochrome_flair`, `lucide_icons` |
| `lib/jt-links.ts`, `lib/jt-color-mode.ts`, `lib/jt-command-menu-shortcut.ts` | full-page links for non-forum paths; the light/dark switch (returns to "follow the device"); whether ⌘K is the menu's or chat's |
