# Changelog

What changed for forums running Jtech Tools. Newest first.

## Unreleased

**New**

- JTech theme: the forum's own theme now ships with the plugin and is installed and kept up to date on every rebuild. It is never made the default; turn it on under Customize → Themes. Switch: `jtech_theme_install`. See [docs/features/jtech-theme.md](docs/features/jtech-theme.md).
- JTech theme: the forum's small theme components are built in, each with its own setting: first-reply prompt, code line numbers, last seen on user cards, first/last post buttons, hidden padlocks, the tablet composer full-screen button, and full-page links to the landing site from posts. It also styles core's category boxes. The theme docs list which components to detach and which to keep.

## 0.5.0 — September 2026

A pass over every module to fix bugs, close permission holes and hand work back to core where core already does it.

**Check after upgrading**

- Moderators now manage categories through core's `moderators_manage_categories`. It's switched on for you if the old module grant was on, and it now covers only categories a moderator can see.
- Gravatar is switched off site-wide (`automatically_download_gravatars`, `gravatar_enabled`) if the old Username avatar module was on.
- Category moderators (Mini-mod) can no longer delete categories, and need `mini_mod_manage_all_categories` to create top-level ones.

**Permissions**

- Mini-mod:
  - Category moderators could make private categories public, hand moderation to any group, and reach categories they couldn't see. All closed.
  - Reopen restrictions now also cover "open" topic timers.
- Moderator tools:
  - Moderators could edit, re-permission or delete admin-only categories. Closed.
  - Every endpoint checks topic visibility.
  - Staff alerts and the notes feed reach only staff who can see the topic. A deleted PM post used to reach every moderator.
  - Checklists no longer leak hidden topics.
  - Whisper conversions are logged in staff actions.

**Fixed**

- Dislike: notification suppression and the audit trail never ran. Likes in restricted categories now never notify, reactions included, and the like totals survive the hourly directory refresh.
- Moderator tools:
  - Non-staff topic lists (/top, /hot, custom sort orders) were re-sorted by bump date. That's removed.
  - Whisper targets can mark a trailing whisper read.
  - Topic pages no longer run one query per post for whisper checks.
  - Whisper recipients get one notification, not two.
  - Concurrent note edits no longer overwrite each other.
- Smart search:
  - Retries keep the search's filters.
  - Only the first page is expanded.
  - Retries no longer fill the search log.
  - A topic isn't listed twice.
  - Extra synonyms apply on every server process.
  - The dictionary was pruned of false and everyday-word synonyms.
- Pop-ups:
  - quiet during Do Not Disturb;
  - usable from the keyboard, with a close button;
  - the preference only shows on your own account page;
  - likes no longer show your own avatar as the actor's.
- Another SMTP: group inbox mail keeps its own server, and the dashboard warns about a relay with no address.
- Translator tweaks: removed the globe-hiding tweak that left old posts untranslatable.

**Removed**

- Username avatar, replaced by core settings. The reset script no longer wipes the system user's and bots' avatars.

## 0.4.0 — September 2026

**Check after upgrading.** If you turned the moderator tools off before August 30, 2026, check them again. An update that day turned `mod_categories_enabled`, `mod_pin_post_enabled` and `mod_notes_feed_enabled` back on by default and cleared saved "off" values. Switch `mod_categories_enabled` off again if you want the module off; it stays off from now on.


- Dumbcourse rebuilt in TypeScript: D-pad and keypad navigation, sign-in from another device, email codes and links, and soft keys that work on more phones.
- REQ-PM: exchange contact details instead of private messages.
- The whole frontend converted to TypeScript.
- Whispers: every path that leaked them outside their audience closed.
- Explanatory text removed from the UI.
- `jtech_enabled` now actually stops every module.
