// The unread badge on topic rows.
import assert from "node:assert/strict";
import { before, test } from "node:test";
import type { TopicListItem } from "../src/types.ts";

type Row = typeof import("../src/ui/topic-row.ts");
let row: Row;

before(async () => {
  await import("./stub-dom.ts");
  row = await import("../src/ui/topic-row.ts");
});

const topic = (t: Partial<TopicListItem>) => t as TopicListItem;

test("Discourse's new_posts alias isn't counted twice", () => {
  // What Discourse sends for a watched topic with 2 new posts.
  assert.equal(row.unreadCount(topic({ unread_posts: 2, new_posts: 2 })), 2);
});

test("either field alone still counts", () => {
  assert.equal(row.unreadCount(topic({ unread_posts: 3 })), 3);
  assert.equal(row.unreadCount(topic({ new_posts: 4 })), 4);
  assert.equal(row.unreadCount(topic({})), 0);
});
