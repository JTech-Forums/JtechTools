# Changelog

What changed for forums running Jtech Tools. Newest first.

## Unreleased

**New**

- JTech theme: the forum's own theme now ships with the plugin and is installed and kept up to date on every rebuild. It is never made the default; turn it on under Customize → Themes. Switch: `jtech_theme_install`. See [docs/features/jtech-theme.md](docs/features/jtech-theme.md).
- JTech theme: on Preferences → Tracking the two cards (categories and tags) sit side by side instead of overlapping, and on 320px phones like a Qin F21 no preferences page scrolls sideways any more.
- JTech theme: a member's own lists redesigned. The messages inbox is the same topic cards as the rest of the forum, bookmarks are a divided card with the bookmark's name as a small label over its topic, and the activity stream (all, replies, likes …) is a card per entry. Same on phones.
- JTech theme: the forum's small theme components are built in, each with its own setting: first-reply prompt, code line numbers, last seen on user cards, first/last post buttons, hidden padlocks, the tablet composer full-screen button, and full-page links to the landing site from posts. It also styles core's category boxes. The theme docs list which components to detach and which to keep.
- JTech theme: the log in and sign up pages redesigned. The form and the other ways in (passkey, and any social logins) sit together on one card, the fields are the theme's 44px controls with their floating labels placed to match, the buttons line up with them, and the footer stays off these pages. Same on phones, where the other ways in move under the form.
- JTech theme: after using the keyboard, opening a dialog (a post's edit history, flagging, the shortcuts help) no longer draws a dark frame around its whole content.
- JTech theme: with the keyboard, you can see which button you're on. Tabbing onto a header icon, a post's buttons, New Topic, a dropdown or a dialog's buttons now shows the same ring links already had (core hid it on buttons and showed a faint tint or nothing). A mouse click still shows no ring.
- JTech theme: grey text is easier to read. Timeline dates, "1 Reply", "view 1 hidden reply", the topic's category in the header, the pinned post badge and other secondary text all reach WCAG AA contrast (4.5:1) in light, dark and Dim; in light mode the palette's medium grey is a shade darker, and in dark mode "view 1 hidden reply" is no longer dark grey on black.
- JTech theme: a softer dark mode, **JTech Dim** (soft grey instead of OLED black), that anyone can pick under Preferences → Interface → Color Palette → Dark mode. OLED black stays the default.
- JTech theme: with the keyboard, links show their whole focus ring. A post's author names, the logo, the topic's title and category in the header, the topic map's avatars, the list's tabs, notifications and images in posts had theirs cut off or hidden, and suggested topics' titles had none. Same on phones.
- JTech theme: on phones and touch screens, small controls are easier to hit. Quick look's eye and the hero's × on cards, the "Back" pill over a topic, a post's date and edit count, the pinned post card's jump arrow, a card's category and tags and a poster's name all take a tap from at least 32px around them (they were 16–22px), without looking any different.
- JTech theme: on phones, the grey scrollbar that ran under every post's row of buttons, and the one down the side of the slide-in panels (the ☰ drawer, the bell's and the avatar's), are gone. They all still scroll by swiping; code blocks, tables and the command menu keep their visible bars.
- JTech theme: a blockquote in Hebrew has its bar on the right, where its text starts, instead of on the far left away from the text. English quotes keep the bar on the left. Same in the composer's rich editor and on the guidelines and FAQ pages.
- JTech theme: on a user card, the REQ-PM button is the same size as Message and Follow above it, instead of a smaller, shorter button.
- JTech theme: on a user's (or group's) card the big avatar sits inside the card instead of sticking out above its top edge over the post behind it. Same on phones.
- JTech theme: highlighted text in posts is a soft band behind the text in its usual colour. It was black text on a dark grey block in light mode (hard to read), and a light grey block with black text in dark mode. Same in the composer.
- JTech theme: the flair on avatars for trust levels, moderators and admins is drawn in black and white with the theme's own marks (a ring for new users, one to three chevrons for trust levels 1–3, a star for 4, a shield for staff) instead of each group's bright colour and icon. Other groups' flair is unchanged. Setting: `monochrome_flair`.
- JTech theme: deleted posts, which staff still see, are a dashed outline over a faint hatch with muted text, and their name, date and buttons are grey, instead of a bright pink block with red everywhere. Deleted small notices (closed, split …) are struck through in grey. Same on phones.
- JTech theme: on a profile, the row of buttons (Message, the notification level, Admin, Follow, REQ-PM, User notes) is one size; three of them were a size smaller and a little shorter. In dark mode the header on every tab but Summary no longer has a darker box inside the card.
- JTech theme: the badges page redesigned. A display title, each badge group as a small label, each badge a card whose description stops at three lines (so a row of cards is no longer as tall as its longest one), and on a badge's own page the people who earned it are cards too. Gold, silver and bronze icons keep their colours. Same on phones.
- JTech theme: on small phones, a topic found in the search and command menu shows its category under the title, so the title isn't cut short.
- JTech theme: on phones the search and command menu sits in the middle of the screen, with the same margin on both sides, instead of against the left edge.
- JTech theme: in a post's edit history, the line under the revision's author and date is the same thin line as the rest of the dialog, instead of a thick grey bar. Same in dark mode.
- JTech theme: the composer's rich editor shows collapsible sections, quotes, link previews and plain blockquotes as they'll look in the post (hairline cards, a chevron, a bar beside a blockquote) instead of core's grey bars and boxes. The chevron still opens and closes a section.
- JTech theme: a quote's buttons to expand it and to jump to the quoted post are easy to see (they were a pale grey on the card) and the same size as each other. Same in dark mode.
- JTech theme: collapsible sections, quotes and link previews in posts are the same hairline card. A section's summary has a chevron that turns when it opens and a rule under it while open (instead of a grey bar with ► / ▼), a quote is one quiet card with who's quoted on top and no bar beside the text, and a link preview has a single border instead of a double ring, with the site's name in grey. Same in the composer's preview and on phones.
- JTech theme: videos in posts have the same rounded corners as the images around them, instead of a square black box. Uploaded videos (before and while they play) and YouTube and Vimeo videos alike.
- JTech theme: every icon in the header is the same size, including chat's and core's ☰, and on phones the search icon no longer has a box around it.
- JTech theme: on phones, writing a new message, the tags box sits under the title instead of running off the right edge of the screen.
- JTech theme: on laptop-sized windows (about 925 to 1320px wide) the reply box ends where the posts end, instead of running past them and over the timeline's buttons beside them.
- JTech theme: on phones, a post's row of buttons no longer scrolls sideways. The buttons are a touch narrower, the row wraps, and when the like count and the buttons don't fit on one line the buttons drop under it against the right edge.
- JTech theme: keys in posts (`<kbd>`) look like the theme's other keycaps, a quiet chip with a thin border and the same rounded corners, instead of core's grey key with a thick bottom edge.
- JTech theme: roomier. Text uses core's own size scale again (16px at "normal", was 15px), the header is taller with 40px buttons and bigger icons, and the sidebar has 36px rows with body-size labels and icons, after people found the forum a size too small and cramped next to Horizon.
- JTech theme: polls follow the theme. The frame has the theme's rounded corners, each result sits on a faint track with rounded ends (so a 0% option still shows its empty bar), the option you voted for is in the text colour, the voter count is a number in the text colour rather than grey, and the settings gear is a flat icon button in both modes instead of a white box in light and a grey one in dark. Same on phones.
- JTech theme: on phones, every suggested topic under a topic shows its reply count at the top right and its date under it. On small phones a long title used to push the count down beside the date, and at 240px the list ran off the screen.
- JTech theme: on small phones (320px wide, like a Qin F21), the Reply button under a topic moves under the other buttons instead of running off the screen and making the page scroll sideways.
- JTech theme: on phones, group cards fit the screen. A long handle like @discourse_ai_users made every card wider than the phone, so the page scrolled sideways; long names now wrap.
- JTech theme: on the groups page, a group's @handle is small and grey under its name again (the forum's group boxes component made it as big and bold as the name), and on 320px phones like a Qin F21 a long one no longer makes every card wider than the screen.
- JTech theme: the groups page redesigned. The name filter, type filter and New Group are a toolbar; each group is a card with its name, @mention, member count in a pill, description and your standing (member, owner, private, automatic); a group's own page has its header on a card and its members in the same table card as the users directory. Same on phones.
- JTech theme: on 320px phones like a Qin F21, the welcome box's quick links show their whole title ("JTech Homepage" wraps onto two lines instead of ending in "…").
- JTech theme: the review queue for staff is quieter. Each item's title row is a sunken strip in the text colour (it was a solid black bar, white in dark mode), Pending is an outlined pill, an empty queue is the same centred card as the other empty pages, and the review count on the avatar is black and white like the bell's instead of red. Same on phones.
- JTech theme: on the People page on phones up to 375px wide, the periods (Day … All time) are two rows of three, so "All time" isn't cut off at the edge.
- JTech theme: phones show the small (square) logo in the header, leaving room for the icons. A mobile logo uploaded in the site settings still wins. Setting: `mobile_small_logo`.
- JTech theme: on phones, "Back" (to where you were before jumping in a topic) is a small glass pill with its arrow above the progress capsule, instead of bare grey text floating over the end of a post.
- JTech theme: the "1 / 4" progress widget on phones (and in desktop windows too narrow for the timeline) is one capsule: the first / last post arrows, the admin wrench and the counter share a glass bar, the counter's fill is a quiet tint rather than a coloured bar, and its numbers are in the text colour. Same on desktop where it shows.
- JTech theme: the selected tab (Latest, a profile's Activity, …) is marked with a thin 1px line that glows a little, with a faint light behind its label, instead of a solid 2px bar. Soft white in dark mode, soft grey in light mode.
- JTech theme: on desktop pages with the sidebar, the composer starts at the same left edge as the page content instead of a little to its left. Its right edge doesn't move.
- JTech theme: the header, page content and footer share one right edge. Suggested topics under a topic and the whole search page now reach it (core stopped them short), and the footer's divider runs between the page's edges instead of fading across the window.
- JTech theme: the search page redesigned. The field has a search glyph and a matching button, "50+ results for" is the page's title with the term in a pill (it used to sit further in than the results below it), bulk select and sort are a toolbar under it, and the results are one divided card with the date above each excerpt and the hit marked rather than bold. Tags and categories come as chips, people as cards, and "No results found" is a card with the Google fallback inside it. Same on phones.
- JTech theme: the avatar no longer opens the same notifications as the bell beside it. Its menu starts on the profile tab (account, preferences, log out), or on the review queue when its badge says something is waiting there.
- JTech theme: "view 1 hidden reply" between posts is a small label centred on a fading hairline, like the topic list's "last visit" line, instead of bold uppercase grey text. Same on phones.
- JTech theme: under a topic, the suggested / new & unread list is a divided card (its column header hidden on phones) and "Want to read more?" reads as a sentence instead of a heading. On phones the footer buttons are all the same size and Reply keeps its word, taking the rest of the row, instead of being one more icon.
- JTech theme: tables in posts are a hairline card: the header row is a sunken strip in small grey type, cells have room around them with a rule between rows, and numbers line up. They no longer lift with a shadow on hover. Wide tables still scroll sideways on phones, with slightly tighter cells there.
- JTech theme: on phones, a poster's title next to their name is a pill the size of the title, instead of a bar across the post.
- JTech theme: Discourse's error page ("Access Denied", a server error, offline) is the same centred card as the empty pages: a small alert mark instead of a giant ":(", the reason as the title, the address it was loading small and quiet, and Go Back as the quieter button beside Try Again. Same on phones.
- JTech theme: empty pages (no messages, no bookmarks, no drafts, no notifications, and the other "nothing here yet" states) are a card in the middle of the space with a small inbox mark, the title and the explanation, instead of a heading and a paragraph in the top left corner of a blank page. The 404 page's title, home button and search box follow the theme's type and controls. Same on phones.
- JTech theme: one shape for each kind of thing, after people found the corners all over the place. Everything you press, type in or pick from (buttons, fields, dropdowns, the composer's toolbar and corner buttons, Discard, the reaction count beside Me too, menu rows) has the same corner, which core had at 0, 10, 12 or 14px; menus and dropdowns now get the theme's card corners as intended; and avatars are rounded boxes like the rest instead of circles (still circles with `corner_style` round). Same on phones.
- JTech theme: under a topic, the tracking menu sits in the row of buttons before Reply, without the sentence explaining the level. The footer lines up with the page above it (sidebar and content) instead of a narrower centred column.
- JTech theme: notifications redesigned, on the page and in the bell's panel. The page's two filters are a toolbar of matching controls and the list is a divided card; unread rows keep a quiet tint with the name in bold, and the small type badge on each avatar is black on white (white on black) instead of the palette's accent colour. The panel's tabs, rows and bottom bar follow the same shapes. Same on phones.
- JTech theme: "See 1 new or updated topic" no longer sits on top of the first topic card on wide screens. It's a centred button above the cards with a gap under it, the same on phones.
- JTech theme: on desktop the list's filters, tabs and New Topic button share one line when they fit. When they don't, the filters move up to a line of their own and the tabs keep New Topic beside them, instead of the tabs disappearing and the buttons running past the page's edge (category pages with subcategories). On narrower windows New Topic shows just its icon, and if the tabs still don't fit they scroll sideways, keeping the current tab in view. On New, the All / Topics / Replies switch no longer sits on the first card.
- JTech theme: the about page redesigned. The forum's name is a display title over its description, the member / admin / moderator / created counts are tiles, admins and moderators are cards with their titles, and "Contact us" and "Site activity" share one ruled card beside them. It uses the page's full width, like the rest of the theme. Same on phones.
- JTech theme: on phones the ⌘K menu (opened from the header's search) drops its keyboard hints: no "esc" keycap beside the ×, no ↵ on the highlighted row, and the search box says "Search or jump to…" instead of a hint that was cut off mid-word.
- JTech theme: in the ? keyboard help, the theme's own shortcuts (g g for Tags, g i for Notifications, …) show their keys in one chip like Discourse's g h, instead of two chips with a gap.
- JTech theme: the ⌘K menu shows each command's keyboard shortcut. Most are Discourse's own (g l for Latest, g n for New, …); the theme adds g g for Tags, g i for Notifications, g e for Preferences, g a for Admin and g o for light / dark, which work anywhere outside a text field and are listed in the ? help.
- JTech theme: the preferences pages redesigned. Each group (Email, Activity Summary, Theme, Color Palette, …) is a card with its name as the title, every field has a quiet label over one of the theme's controls, help text sits small underneath, and Save Changes closes the form on a ruled bar instead of floating below it. Same on phones.
- JTech theme: on wide screens the header's search field sits in the middle of the bar. On narrower screens, touch screens and while a topic's title is in the header it stays in the icon row.
- JTech theme: the guidelines, FAQ, terms and privacy pages read like a post: a measured column at the post's text size and line height, headings with room above them, lists and links styled as in posts, and the staff "Edit this page" link quiet under the nav. Same on phones.
- JTech theme: Discourse's icons are drawn with Lucide's thin outline set (as ChatGPT and Gemini use) instead of Font Awesome: the header, sidebar, post menu, composer, notifications and category icons. Liked and bookmarked keep a filled shape. Brand logos and icons without a Lucide match stay Font Awesome. Setting: `lucide_icons`.
- JTech theme: the tags page redesigned. Each tag is a chip (# name, with its count in a small pill instead of "x 190"), lists wrap to fill the page rather than three floated columns, "Sort by" is a pair of pills, and the admin's create field and menu sit beside the title. Same on phones.
- JTech theme: a login gate for chosen categories and tags replaces the Gated Topics in Category component. Logged-out visitors see the topic's first lines fade into a card to log in or create an account, with a link to the open categories. Settings: `gated_categories`, `gated_tags`.

**Fixed**

- Moderator tools: in a narrow window, the first-post checklist's acceptance log scrolls in its own box instead of the whole dialog scrolling sideways.

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
