import { get } from "@ember/object";
import type Composer from "discourse/models/composer";

export interface ListingTopicFields {
  listing_format_topic?: boolean;
  listing_format_fields?: string[];
}

// The composer model as the listing form uses it. The listing* properties
// are set with Ember's `set`, so they're read with `get` to stay reactive.
export type ListingComposer = Composer & {
  action?: string;
  reply?: string;
  topic?: ListingTopicFields | null;
  listingFields?: string[] | null;
  listingValues?: Record<string, string> | null;
  // The editor's own text while a save is under way, put back if it fails.
  listingBody?: string | null;
};

export function listingFields(model: ListingComposer): string[] {
  return (get(model, "listingFields") as string[] | null | undefined) ?? [];
}

export function missingValues(model: ListingComposer): string[] {
  const values = model.listingValues ?? {};
  return listingFields(model).filter((field) => !values[field]?.trim());
}

// The post as the server checks it: one "Field: value" line each, then
// whatever was written in the editor (pictures, details).
export function assemble(model: ListingComposer): string {
  const values = model.listingValues ?? {};
  const lines = listingFields(model).map(
    (field) => `${field}: ${(values[field] ?? "").trim()}`
  );
  const body = (model.reply ?? "").trim();
  return body ? `${lines.join("\n")}\n\n${body}` : lines.join("\n");
}
