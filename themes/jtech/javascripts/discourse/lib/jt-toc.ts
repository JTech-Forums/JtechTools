import { settings } from "virtual:theme";

export interface TocHeading {
  level: number;
  text: string;
  // the name of core's anchor in the heading (a.anchor[name])
  anchor: string;
}

// Fewer headings than this and a contents list isn't worth its room.
export const MIN_HEADINGS = 3;

// The marker DiscoTOC's composer button wrote into a first post; posts that
// carry it keep their contents.
export const TOC_MARKER = '<div data-theme-toc="true"> </div>';

export const isMarked = (cooked: string) =>
  cooked.includes('data-theme-toc="true"');

// Headings at the post's top level (or in a [wrap] block), not ones inside
// quotes, details or tables.
const HEADINGS = ["h1", "h2", "h3", "h4"]
  .flatMap((h) => [`:scope > ${h}`, `:scope > .d-wrap > ${h}`])
  .join(", ");

export function headingsIn(root: ParentNode): TocHeading[] {
  const headings: TocHeading[] = [];
  for (const heading of root.querySelectorAll(HEADINGS)) {
    const anchor = heading
      .querySelector("a.anchor[name]")
      ?.getAttribute("name");
    const text = heading.textContent?.trim();
    if (anchor && text) {
      headings.push({ level: Number(heading.tagName[1]), text, anchor });
    }
  }
  return headings;
}

const parsed = new Map<string, TocHeading[]>();

// From a post's cooked HTML, for when the post isn't on screen. A parsed
// document never fetches its images.
export function headingsInCooked(cooked: string): TocHeading[] {
  let headings = parsed.get(cooked);
  if (!headings) {
    const body = new DOMParser().parseFromString(cooked, "text/html").body;
    headings = headingsIn(body);
    parsed.set(cooked, headings);
  }
  return headings;
}

const listed = (ids: string) => ids.split("|").filter(Boolean).map(Number);

// A first post gets contents when it carries the marker or its topic is in
// table_of_contents_categories (or a subcategory of one), with enough headings.
export function tocApplies(
  marked: boolean,
  category?: { id?: number; parent_category_id?: number }
) {
  if (!settings.table_of_contents) {
    return false;
  }
  const ids = listed(settings.table_of_contents_categories);
  return (
    marked ||
    [category?.id, category?.parent_category_id].some(
      (id) => id !== undefined && ids.includes(id)
    )
  );
}

// Each heading's indent, counted from the shallowest one listed.
export function depth(heading: TocHeading, headings: TocHeading[]) {
  return heading.level - Math.min(...headings.map((h) => h.level));
}
