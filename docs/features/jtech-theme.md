# JTech theme

The forum's own theme ships with the plugin: AMOLED black and pure white, monochrome everywhere, hairline borders, rounded ("squircle") corners and the Geist typeface. Light and dark are exact inverses and follow each person's colour-mode choice.

What it adds on top of a restyle:

- **Topic cards** instead of table rows, with the first image beside the title and a Quick look preview.
- **A front-page hero** with search and quick links, **category and tag banners**, and a **footer** with link columns.
- **⌘K / Ctrl+K command menu** to jump to pages, categories, topics and people. The header's search field opens it. For people who can use chat, ⌘K stays chat's channel switcher (core binds it) and the menu opens from the search field only; "/" still opens Discourse's own search.
- **Header**: search (in the middle of the bar on wide screens), JTech homepage, messages and notifications (with unread counts), light/dark, new topic. Staff keep core's review-queue badge on their avatar.
- **Sidebar**, **profiles**, **users directory** and **empty pages** redesigned; site notices get a dismiss button.
- A **login gate** for chosen categories and tags: logged-out visitors see a topic's first lines fade into a card to log in or create an account.
- An overlay page scrollbar, a back-to-top button, reading progress, language labels on code blocks, category icons on the categories page.

Each of those has its own switch in the theme's settings.

The command menu shows each command's keyboard shortcut beside it: Discourse's own (`g l` Latest, `g n` New, …), plus `g g` Tags, `g i` Notifications, `g e` Preferences, `g a` Admin and `g o` light / dark, which the theme adds and lists in the `?` help. They work anywhere outside a text field; in the open menu, typing searches.

## Installing it

Installing or updating the plugin (a rebuild) installs the theme and keeps it up to date. It runs with the database migrations, the way Discourse installs its own themes.

The plugin **never** makes it the default theme and never offers it to users. To use it, go to **Admin → Customize → Themes → JTech** and:

1. Preview it as staff first (**Preview**, or `?preview_theme_id=<id>`).
2. Attach the components you still want; [Your current components](#your-current-components) says which ones JTech already covers and which clash with it.
3. Make it the default, or let users choose it.

Your choices there stay put: the default and user-selectable choice, attached components, the theme's settings and any colour-palette or theme site-setting changes all survive updates. What doesn't survive is editing the theme's files in the admin theme editor (CSS, JS): the next update replaces them with the plugin's copy. Put local tweaks in a small component instead, or change `themes/jtech` in the plugin.

- **Already had JTech installed by hand** (from its old Git repo, as an uploaded zip, or synced with the theme CLI)? The first install takes that theme over and updates it in place, so its default status, components and settings carry on and you don't get a second "JTech". It stops following the Git repo from then on.
- **Deleting the theme** keeps it deleted. To bring it back, turn `jtech_theme_install` off and on again, or run `rake jtech:theme:install`.
- **Turning off `jtech_theme_install`** stops installs and updates. The installed theme stays as it is. Turning it back on installs straight away (it doesn't wait for a rebuild).

## Your current components

Several components on the forum's Default theme are built into JTech, and some clash with it. Detach those when you switch; the rest keep working as they are.

**Built in (detach the component; the JTech setting is on by default):**

| Component | JTech setting | Notes |
| --- | --- | --- |
| Header Glass Fork JUNIV | — | JTech's own header. |
| Welcome Link Banner | `hero_*` | The hero; its four links are the hero's defaults. |
| Landing page links (leave the forum) | — | Header, hero, footer and links in posts all open non-forum pages as a page load. |
| Be the first to reply | `first_reply_prompt` | Copy the component's hidden categories into `first_reply_prompt_hidden_categories` (13, 15, 22, 25, 28, 29, 30, 31, 34, 49 on the forum today). |
| Discourse Code Block Line Numbers | `code_line_numbers` | A gutter beside the code, so copying a block copies only the code. |
| Hide Lock Badge Icon | `hide_lock_icons` | |
| Last Seen User Card | `user_card_last_seen` | People who turn on "hide my public profile and presence" are left out. That preference also replaces the CSS that hides it for one user. |
| Discourse Jump Buttons | `topic_jump_buttons` | Under the timeline, and beside the progress button on phones. |
| Unhide composer fullscreen toggle for tablets | — | Always on. |
| Sidebar Theme Toggle | `color_mode_toggle` | Keep the component only if people should also be able to switch to another theme. |
| Gated Topics in Category | `gated_categories`, `gated_tags` | Copy the component's categories and tags (General, Android Apps, Android ROMs, Android Guides and the `roms` tag on the forum today). Off until you list some. Like the component, it's for logged-out visitors only. |
| Modern Category + Group Boxes | — | Set the site setting `desktop_category_page_style` to **Boxes**: JTech styles core's category boxes, which already show each category's icon. |

**Clash with JTech (detach):** discourse-left-side-burger (JTech keeps the ☰ at the right), Discourse Avatar Component (JTech sets avatar shape), Full width (JTech sets the page width), Density Toggle (JTech's type scale), Topic List Item Click Animation (JTech's cards have their own press feedback), User Card Directory and Users Top Nav (JTech's People page).

**Keep as they are:** Admin Warnings, Auto linkify words, Copy post button, DiscoTOC, Highlight to Search, Sidebar Menu Reorder, Wikipedia Lookup, Messages section for sidebar, Post Badges, Post Image Carousel, QR Code Shareables, Quick Profile Links Menu, Reader Mode, Reply Templates, Shared Draft Button, Topic PDF Download Button, Unanswered Filter, Voice Recorder. JTech's styles cover the ones that draw in the page.

**Not real restrictions:** JTech's login gate (like "Gated Topics in Category" before it) and "Restricted reactions (like) by group" only hide things in the browser. The topics are still sent to logged-out visitors (`/t/….json` reads them), and the like API still accepts likes. If those need to hold, they belong on the server, in category permissions or the plugin.

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| `jtech_theme_install` | on | Install the bundled theme and update it when the plugin updates. Never made the default. Turning it on installs now and brings back a deleted theme. |

The look itself is configured in the theme's own settings (corner style, cards, hero text and links, footer links, header home link and the other switches).

## Things outside the theme

- **Brand assets.** The JTech mark, app icon and favicon are in [`docs/theme/brand/`](../theme/brand/). They're site settings (`logo_small`, `favicon`, `apple_touch_icon`…), so they apply to every theme; upload them yourself if you want them. On phones the header shows `logo_small` (the square mark) instead of the wide logo, unless a `mobile_logo` is uploaded; theme setting `mobile_small_logo`. Setting `base_font` and `heading_font` to `system` stops browsers downloading Roboto, which JTech doesn't use.
- **Card thumbnails.** The theme asks Discourse for 320 px topic thumbnails, so after it's installed Sidekiq makes them for listed topics once, a few at a time.
- **Links to the landing site** (`/home`, `/dumb`, `/terms`…): the header, hero, footer and links inside posts open any same-site link that isn't a forum page as a normal page load, so they reach the landing site instead of the forum's 404 page.

## Before updating Discourse

A theme that breaks on a new Discourse version doesn't take the forum down: CSS keeps working, but all of JTech's JavaScript stops (hero, cards, footer) and admins see "a theme has errors". Check on a local forum first. See [development/jtech-theme.md](../development/jtech-theme.md#before-updating-discourse).
