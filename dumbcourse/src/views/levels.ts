// Watching / Tracking / Normal / Muted, for a topic or a category.

import { errorMessage, post } from "../api.ts";
import { invalidate } from "../cache.ts";
import { category } from "../site.ts";
import { actionSheet, toast, type SheetItem } from "../ui/layers.ts";

export const LEVELS = [
  {
    id: 3,
    label: "Watching",
    icon: "watch",
    topic: "Every reply",
    category: "Every new post",
  },
  {
    id: 2,
    label: "Tracking",
    icon: "eye",
    topic: "Count new replies",
    category: "Count new replies",
  },
  {
    id: 1,
    label: "Normal",
    icon: "bell",
    topic: "Mentions and replies to me",
    category: "Mentions and replies to me",
  },
  {
    id: 0,
    label: "Muted",
    icon: "mute",
    topic: "Nothing",
    category: "Hidden from Latest",
  },
];

export function levelLabel(id: number | null | undefined): string {
  for (let i = 0; i < LEVELS.length; i++)
    if (LEVELS[i].id === id) return LEVELS[i].label;
  return "Normal";
}

export function topicLevelSheet(
  topicId: number,
  current: number,
  onChange: (level: number) => void
): void {
  const items: SheetItem[] = LEVELS.map((l) => ({
    label: l.label,
    icon: l.icon,
    hint: l.topic,
    active: l.id === current,
    run: () => {
      post(`/t/${topicId}/notifications.json`, {
        notification_level: l.id,
      }).then(
        () => {
          onChange(l.id);
          toast(`${l.label}.`, "success");
        },
        (e: unknown) => toast(errorMessage(e), "error")
      );
    },
  }));
  actionSheet("Notifications for this topic", items);
}

export function categoryLevelSheet(categoryId: number): void {
  const c = category(categoryId);
  const current = c
    ? (c as unknown as { notification_level?: number }).notification_level
    : undefined;
  const items: SheetItem[] = [
    { id: 3, label: "Watching" },
    { id: 4, label: "Watching first post" },
    { id: 2, label: "Tracking" },
    { id: 1, label: "Normal" },
    { id: 0, label: "Muted" },
  ].map((l) => ({
    label: l.label,
    active: l.id === current,
    run: () => {
      post(`/category/${categoryId}/notifications.json`, {
        notification_level: l.id,
      }).then(
        () => {
          if (c)
            (
              c as unknown as { notification_level?: number }
            ).notification_level = l.id;
          invalidate("/c/");
          toast(`${l.label}.`, "success");
        },
        (e: unknown) => toast(errorMessage(e), "error")
      );
    },
  }));
  actionSheet(c ? c.name : "Category", items, {
    subtitle: "Notifications for this category",
  });
}
