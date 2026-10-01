# JTech theme

The forum's own theme ships with the plugin: AMOLED black and pure white, monochrome everywhere, hairline borders, rounded ("squircle") corners and the Geist typeface. Light and dark are exact inverses and follow each person's colour-mode choice.

What it adds on top of a restyle:

- **Topic cards** instead of table rows, with the first image beside the title and a Quick look preview.
- **A front-page hero** with search and quick links, **category and tag banners**, and a **footer** with link columns.
- **⌘K / Ctrl+K command menu** to jump to pages, categories, topics and people. The header's search field opens it. For people who can use chat, ⌘K stays chat's channel switcher (core binds it) and the menu opens from the search field only; "/" still opens Discourse's own search.
- **Header**: search, JTech homepage, messages and notifications (with unread counts), light/dark, new topic. Staff keep core's review-queue badge on their avatar.
- **Sidebar**, **profiles**, **users directory** and **empty pages** redesigned; site notices get a dismiss button.
- An overlay page scrollbar, a back-to-top button, reading progress, language labels on code blocks, category icons on the categories page.

Each of those has its own switch in the theme's settings.

## Installing it

Installing or updating the plugin (a rebuild) installs the theme and keeps it up to date. It runs with the database migrations, the way Discourse installs its own themes.

The plugin **never** makes it the default theme and never offers it to users. To use it, go to **Admin → Customize → Themes → JTech** and:

1. Preview it as staff first (**Preview**, or `?preview_theme_id=<id>`).
2. Attach the same components as your current theme, **except** "Header Glass Fork JUNIV" (JTech has its own header) and "Welcome Link Banner" (replaced by the hero; its four links are the hero's defaults).
3. Make it the default, or let users choose it.

Your choices there stay put: the default and user-selectable choice, attached components, the theme's settings and any colour-palette or theme site-setting changes all survive updates. What doesn't survive is editing the theme's files in the admin theme editor (CSS, JS): the next update replaces them with the plugin's copy. Put local tweaks in a small component instead, or change `themes/jtech` in the plugin.

- **Already had JTech installed by hand** (from its old Git repo)? The first install takes that theme over and updates it in place, so its default status, components and settings carry on and you don't get a second "JTech". It stops following the Git repo from then on.
- **Deleting the theme** keeps it deleted. To bring it back, turn `jtech_theme_install` off and on again, or run `rake jtech:theme:install`.
- **Turning off `jtech_theme_install`** stops installs and updates. The installed theme stays as it is. Turning it back on installs straight away (it doesn't wait for a rebuild).

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| `jtech_theme_install` | on | Install the bundled theme and update it when the plugin updates. Never made the default. Turning it on installs now and brings back a deleted theme. |

The look itself is configured in the theme's own settings (corner style, cards, hero text and links, footer links, header home link and the other switches).

## Things outside the theme

- **Brand assets.** The JTech mark, app icon and favicon are in [`docs/theme/brand/`](../theme/brand/). They're site settings (`logo_small`, `favicon`, `apple_touch_icon`…), so they apply to every theme; upload them yourself if you want them. Setting `base_font` and `heading_font` to `system` stops browsers downloading Roboto, which JTech doesn't use.
- **Card thumbnails.** The theme asks Discourse for 320 px topic thumbnails, so after it's installed Sidekiq makes them for listed topics once, a few at a time.
- **Links to the landing site** (`/home`, `/dumb`, `/terms`…): the header, hero and footer open any same-site link that isn't a forum page as a normal page load, so they reach the landing site instead of the forum's 404 page. Links inside posts still need the "Landing page links (leave the forum)" component.

## Before updating Discourse

A theme that breaks on a new Discourse version doesn't take the forum down: CSS keeps working, but all of JTech's JavaScript stops (hero, cards, footer) and admins see "a theme has errors". Check on a local forum first. See [development/jtech-theme.md](../development/jtech-theme.md#before-updating-discourse).
