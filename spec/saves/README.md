# Category-save regression suite

A focused, separate suite that exercises every meaningful variant of a category save (`PUT /categories/:id.json` and `POST /categories.json`) as a moderator under this plugin, and asserts each one **does not return 500**.

It exists because the main `spec/` suite covers the *Guardian gate* (can a moderator reach the save?) but not the *save chain itself* (does the save complete cleanly once the gate is open?). Those are different code paths and they fail in different ways.

## The bug I think I found

While testing the plugin on a live forum, a moderator-initiated category edit save returned **HTTP 500** with an HTML error page instead of JSON. The browser console showed:

```
PUT /categories/4 → 500 Internal Server Error
SyntaxError: Unexpected token '<', "<!DOCTYPE "... is not valid JSON
    at saveCategory (...)
```

The `JSON.parse` exception is a *symptom* — Ember tried to parse Rails' default HTML 500 page as JSON. The real fault is an unhandled exception somewhere in `CategoriesController#update`'s save chain.

### Hypothesis

The grant in this plugin is given to the **built-in moderators group** (staff, `is_admin? == false`). Core Discourse normally never lets a non-admin staff user edit categories at all, so some sub-operation in the save chain — most likely group-permission updates or another admin-gated bookkeeping step — branches on `is_admin?` and falls into an unhandled path when a moderator hits it.

The original `alltechdev/discourse-mini-mod` plugin doesn't hit this because its grant targets **non-staff category-group moderators**, which is a code path core already supports through `enable_category_group_moderation`.

### What this suite does

Each spec issues a single save variant as a moderator and asserts the response is **not 500**. A `200` is ideal; a `422` (JSON validation error) is acceptable — the goal is to surface which exact save shape crashes the server, not to lock in particular response codes.

The variants are split by which Discourse code path they exercise:

| File | What it saves |
|------|---------------|
| `basic_save_spec.rb` | name, color, text_color, description, slug |
| `permissions_save_spec.rb` | `permissions[group_name]` mappings — the leading 500 suspect |
| `custom_fields_save_spec.rb` | category `custom_fields` hash |
| `settings_save_spec.rb` | position, sort_order, search_priority, auto_close_hours, default_view, etc. |
| `parent_change_spec.rb` | reparenting a category |
| `create_variants_spec.rb` | `POST /categories.json` with each of the above shapes |
| `approval_save_spec.rb` | "Require moderator approval on new topics" — every known param shape, plus `reviewable_by_group_id`. The "except TL3" half is the site setting `approve_new_topics_unless_trust_level`, admin-only and out of scope for the category save. |

Each spec runs the same save as an admin as a control — if the admin save also 500s, the bug is in core/another plugin, not us.

## Running locally

From your Discourse checkout with the plugin mounted at `plugins/discourse-mod`:

```bash
bundle exec rspec plugins/discourse-mod/spec/saves --format documentation
```

## CI

The dedicated workflow `.github/workflows/save-tests.yml` runs only this folder on every push and PR. It's separate from the main `plugin-tests.yml` so a save-chain regression shows up as its own failing check.
