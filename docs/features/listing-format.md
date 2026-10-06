# Listing format: sale threads that stay tidy

For threads like *Hardware: phones and computers for sale*, where every post is a listing. In the topics you choose, a post has to follow the format, or it's turned away with the reason before it's saved.

- **A form for the fields.** Pressing Reply in one of these topics opens the composer with a box for each field (Item, Condition, Price) above the editor. The labels can't be changed; pictures and details go in the editor. The post comes out as one `Field: value` line each, then the rest.
- **REQ-PM, not replies.** Each listing has the seller's REQ-PM button where Reply used to be. Buyers request the seller's contact details there instead of commenting in the thread. It's the same REQ-PM window as on a user card, so it's only there for people who can use REQ-PM (`reqpm_allowed_groups`), and the seller chooses what to send. A comment such as "still available?" isn't a listing, so it's turned away.
- **Fields.** Posts made another way (editing, Dumbcourse, the API) need every field on its own line, such as `Price: $120`. Upper or lower case, bold, bullets and headings are fine. Fields inside a quote don't count.
- **No outside links.** Links to other sites (eBay, Amazon, a store) are turned away, whether they're links or typed as text like `ebay.com/itm/123`. Email addresses, phone numbers, links to the forum and uploaded pictures are fine.
- **Posts from before are kept.** Adding a topic never hides or deletes what's already there. An older post can still be edited (to mark it sold, say) without adding the fields; the edit just can't add an outside link.
- **Edits.** A listing can't lose a field or gain an outside link by being edited.
- **Staff** don't have to follow it, and keep their Reply buttons, so moderators can post reminders and answer people (`listing_format_exempt_groups`).

To explain the format before people post, add a [topic checklist](moderator-tools.md#checklists) to the same topic.

## Choosing topics

Put the topic's number, or paste its address, in `listing_format_topics`. For `https://jtechforums.org/t/hardware-phones-computers-for-sale-thread/32/232` that's topic 32; pasting the whole address works too.

## Settings

Admin → Plugins → Jtech Tools → **Listing format**. The full text of each setting is shown next to it in the admin.

| Setting | Default | What it does |
| --- | --- | --- |
| `listing_format_enabled` | `true` | Makes posts in the topics below follow a set format, for sale threads where every post is a listing. |
| `listing_format_topics` | (none) | Topics where the format applies. |
| `listing_format_fields` | `Item\|Condition\|Price` | Lines each listing needs, in any order. |
| `listing_format_block_links` | `true` | Turns away posts in these topics that link to other sites, typed or as a link. |
| `listing_format_exempt_groups` | `3` | Groups who can post in these topics without following the format, for reminders and staff notes. |

[← All features](../README.md#features)
