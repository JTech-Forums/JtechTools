# Mini-mod

Mini-mod gives *category moderators* some extra rights normally reserved for staff. Category moderators are people who moderate a category through a group (core's `enable_category_group_moderation`). It never changes anything for site moderators or admins.

What it can grant, each with its own switch:

- create and edit categories;
- move topics into the categories they moderate;
- edit topics across the site;
- create and rename tags.

What it never grants:

- reaching a category they can't see;
- deleting categories;
- changing who can see or moderate a category, its incoming email, review groups, position or custom fields. New subcategories copy their parent's security and moderators.
- reordering the site's categories, uploading tags or deleting unused tags;
- editing private messages, archived topics or the TOS/FAQ/privacy pages.

`mini_mod_manage_all_categories` widens the grants from "the categories they moderate" to "every category they can see". It's the widest switch here, so turn it on deliberately.

Mini-mod can also take rights *away*:

- **Posting in closed topics**, from category moderators or trust level 4 users.
- **Reopening closed topics**, from the same groups. This covers "open" topic timers too.

These restrictions are off by default, so core behavior is restored until you switch them on.

## Settings

Admin → Plugins → Jtech Tools → **Mini-mod**. The full text of each setting is shown next to it in the admin.

| Setting | Default | What it does |
| --- | --- | --- |
| `mini_mod_enabled` | `false` | Master switch for Mini-mod. |
| `mini_mod_manage_all_categories` | `false` | Scope for the grants below. |
| `mini_mod_can_create_categories` | `true` | Let category group moderators create categories. |
| `mini_mod_can_edit_categories` | `true` | Let category group moderators open the category settings screens and save changes, for the categories they moderate — or for every category they can see when "Mini mod manage all categories" is on. |
| `mini_mod_can_edit_topics` | `true` | Let category group moderators edit any topic they can see and post in — title, category, tags and first post — unless the first post is locked. |
| `mini_mod_can_move_topics` | `true` | Let category group moderators move topics into the categories they moderate, even where they couldn't start a topic themselves. |
| `mini_mod_manage_tags` | `false` | Let category group moderators create, rename and delete tags they can see and reach the tag administration screens. |
| `mini_mod_can_post_in_closed_topics` | `false` | A restriction, not a grant. |
| `mini_mod_can_reopen_topics` | `false` | A restriction, not a grant. |
| `tl4_can_post_in_closed_topics` | `false` | A restriction, not a grant, and it reaches every trust level 4 user on the site — not only category group moderators. |
| `tl4_can_reopen_topics` | `false` | A restriction, not a grant, and it reaches every trust level 4 user on the site — not only category group moderators. |

[← All features](../README.md#features)
