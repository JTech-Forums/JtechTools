# Jtech Tools

One Discourse plugin with everything JTech Forums runs on top of core. Nine features, each with its own on/off switch in **Admin → Settings → Jtech**.

## Install

```bash
cd /var/discourse
# add to containers/app.yml under hooks → after_code → cmd:
#   - git clone https://github.com/JTech-Forums/JtechTools.git jtech-tools
./launcher rebuild app
```

Master switch: `jtech_enabled`. Every feature below also has its own switch, so you can turn things off one at a time.

## What's in it

### Disteleplus — team chat, bridged to Telegram
A private one-room chat inside Discourse for staff (or any groups you allow), mirrored both ways with a Telegram group.

- Opens as a small drawer bottom-right (like Discourse Chat) or full page; always full page on phones.
- Messages, replies, edits, deletes, reactions, images, files, video, voice notes (record right in the composer), polls from Telegram.
- Right-click a message: react, reply, copy text, copy link, quote into a new topic, edit, delete. Double-tap to react.
- `@mentions` and `:emoji:` suggestions, emoji picker, paste or drag files in, drafts kept while you browse.
- Search across the conversation. Link previews. "Someone is typing" indicators.
- Unread badge on the header icon and in the browser tab; notifications only when you're @mentioned.
- Message text is encrypted in the database.
- Telegram side: people you map post as their Discourse account; everyone else shows with their Telegram name. Discourse messages arrive in Telegram with the author's name linked to their profile.
- Optional: announce new forum posts into the Telegram group (by category / tag).
- Optional: mirror the review queue (flags, posts awaiting approval) into a Telegram topic with **Approve / Deny** buttons for mapped staff.
- Setup is done from inside Telegram with `/disteleplus_setup`; there's a "send test message" button and problems show on the admin dashboard.

### Moderator tools
- **Whispers** — reply to specific people inside a topic; others don't see it.
- **Private notes** on topics, with reply threads, visible to staff only.
- **Staff alerts** — every moderator is told when someone deletes a post, approves/rejects a queued post, adds a user note or a flag note. Shows in the bell and in a shield tab.
- **Checklists** — first-post checklists, targeted checklists for specific users/groups, topic prompt checklists.
- **Topic tools** — pinned messages in topics, footer messages, reply approval.
- Every one of these rights is its own toggle.

### Mini-mod
Gives category moderators (people who moderate a category through a group) extra powers normally reserved for staff: create/edit categories, edit and move topics, manage tags, etc. Each power is a separate switch.

### Dislike (phantom reactions)
In categories you pick, likes stop mattering: they're hidden from history, don't count toward leaderboards, and the like notification is quietly removed. Optionally hide the like button entirely or allow it only for certain groups.

### Smart search
When a search finds too little, it quietly retries with synonyms (English dictionary + a short list of tech abbreviations like `js`/`javascript`, `k8s`/`kubernetes`) and merges the results. Runs locally, no API keys. If anything goes wrong you just get normal search results.

### Desktop pop-up notifications
A small card in the top-right corner when you get a notification, with the person's avatar, the topic title and a preview. Click it to jump there. Desktop only, each user turns it on in their account settings.

### Dumbcourse
A simplified web app version of the forum at `/dumb` for basic devices: reading, replying, reactions, push notifications, spell check. Uses the forum's own reactions and custom emoji.

### Another SMTP
Send forum email through a different mail server than the one in `app.yml` — host, port, TLS, login, and optional "from" address rewriting, all from admin settings.

### Translator tweaks
Small fixes on top of the official Translator plugin (better foreign-language detection, backfill for old posts).

## Telegram setup (5 minutes)

1. In Telegram, message **@BotFather**: `/newbot` → copy the token. Then `/setprivacy` → **Disable** (otherwise the bot can't read the group).
2. Add the bot to your group and make it an **admin**.
3. In Discourse: **Admin → Settings → Jtech — Disteleplus** → paste the token, pick who may use the chat (`disteleplus_allowed_groups`, default: staff), turn on `disteleplus_enabled`, press **Register Telegram webhook**.
4. In the Telegram group, send `/disteleplus_setup` and follow the short checklist (`/disteleplus_bind_general`, optionally `/disteleplus_bind_uploads`, `/disteleplus_bind_reports`).
5. Send a message from each side to check.

Known limits (Telegram's rules, not ours): the bot can't delete messages older than 48 hours, can't see when Telegram users are typing, can only show one reaction per message, and if your group is converted to a supergroup the chat ID changes — bind it again.

## Notes

- Nothing here requires the official Discourse Chat plugin. If you're moving from the old Chat-based bridge, an admin can import the old channel (`POST /jtech-disteleplus/legacy-import`, check progress with `GET`) before switching Chat off. Nothing is deleted from the old Chat data.
- Screenshots of the features are in `docs/screenshots`.
