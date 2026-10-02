# Changelog

What changed for forums running Jtech Tools. Newest first.

## Unreleased

**New**

- JTech theme: the forum's own theme now ships with the plugin and is installed and kept up to date on every rebuild. It is never made the default; turn it on under Customize → Themes. Switch: `jtech_theme_install`. See [docs/features/jtech-theme.md](docs/features/jtech-theme.md).
- JTech theme: the forum's small theme components are built in, each with its own setting: first-reply prompt, code line numbers, last seen on user cards, first/last post buttons, hidden padlocks, the tablet composer full-screen button, and full-page links to the landing site from posts. It also styles core's category boxes. The theme docs list which components to detach and which to keep.
- JTech theme: a softer dark mode, **JTech Dim** (soft grey instead of OLED black), that anyone can pick under Preferences → Interface → Color Palette → Dark mode. OLED black stays the default.
- JTech theme: the flair on avatars for trust levels, moderators and admins is drawn in black and white with the theme's own marks (a ring for new users, one to three chevrons for trust levels 1–3, a star for 4, a shield for staff) instead of each group's bright colour and icon. Other groups' flair is unchanged. Setting: `monochrome_flair`.
- JTech theme: every icon in the header is the same size, including chat's and core's ☰, and on phones the search icon no longer has a box around it.
- JTech theme: roomier. Text uses core's own size scale again (16px at "normal", was 15px), the header is taller with 40px buttons and bigger icons, and the sidebar has 36px rows with body-size labels and icons, after people found the forum a size too small and cramped next to Horizon.
- JTech theme: phones show the small (square) logo in the header, leaving room for the icons. A mobile logo uploaded in the site settings still wins. Setting: `mobile_small_logo`.
- JTech theme: the header, page content and footer share one right edge. Suggested topics under a topic and the whole search page now reach it (core stopped them short), and the footer's divider runs between the page's edges instead of fading across the window.
- JTech theme: the avatar no longer opens the same notifications as the bell beside it. Its menu starts on the profile tab (account, preferences, log out), or on the review queue when its badge says something is waiting there.
- JTech theme: on phones, a poster's title next to their name is a pill the size of the title, instead of a bar across the post.
- JTech theme: under a topic, the tracking menu sits in the row of buttons before Reply, without the sentence explaining the level. The footer lines up with the page above it (sidebar and content) instead of a narrower centred column.
- JTech theme: on desktop the list's filters, tabs and New Topic button share one line when they fit. When they don't, the filters move up to a line of their own and the tabs keep New Topic beside them, instead of the tabs disappearing and the buttons running past the page's edge (category pages with subcategories). On narrower windows New Topic shows just its icon, and if the tabs still don't fit they scroll sideways, keeping the current tab in view. On New, the All / Topics / Replies switch no longer sits on the first card.
- JTech theme: the ⌘K menu shows each command's keyboard shortcut. Most are Discourse's own (g l for Latest, g n for New, …); the theme adds g g for Tags, g i for Notifications, g e for Preferences, g a for Admin and g o for light / dark, which work anywhere outside a text field and are listed in the ? help.
- JTech theme: the preferences pages redesigned. Each group (Email, Activity Summary, Theme, Color Palette, …) is a card with its name as the title, every field has a quiet label over one of the theme's controls, help text sits small underneath, and Save Changes closes the form on a ruled bar instead of floating below it. Same on phones.
- JTech theme: on wide screens the header's search field sits in the middle of the bar. On narrower screens, touch screens and while a topic's title is in the header it stays in the icon row.
- JTech theme: Discourse's icons are drawn with Lucide's thin outline set (as ChatGPT and Gemini use) instead of Font Awesome: the header, sidebar, post menu, composer, notifications and category icons. Liked and bookmarked keep a filled shape. Brand logos and icons without a Lucide match stay Font Awesome. Setting: `lucide_icons`.
- JTech theme: a login gate for chosen categories and tags replaces the Gated Topics in Category component. Logged-out visitors see the topic's first lines fade into a card to log in or create an account, with a link to the open categories. Settings: `gated_categories`, `gated_tags`.

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
