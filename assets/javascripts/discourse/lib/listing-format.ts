import { get } from "@ember/object";
import type Composer from "discourse/models/composer";

export interface ListingChoice {
  multiple: boolean;
  options: string[];
}

export interface ListingTopicFields {
  listing_format_topic?: boolean;
  listing_format_fields?: string[];
  listing_format_choices?: Record<string, ListingChoice>;
  listing_format_editor_field?: string;
}

// What the reply form needs from the topic, copied onto the composer when
// it opens.
export interface ListingSetup {
  fields: string[];
  choices: Record<string, ListingChoice>;
  // The section the editor fills (pictures); null when the editor's text
  // goes after the sections instead.
  editorField: string | null;
}

// The composer model as the listing form uses it. The listing* properties
// are set with Ember's `set`, so they're read with `get` to stay reactive.
export type ListingComposer = Composer & {
  action?: string;
  reply?: string;
  topic?: ListingTopicFields | null;
  listing?: ListingSetup | null;
  listingValues?: Record<string, string> | null;
  listingPicked?: Record<string, string[]> | null;
  // The editor's own text while a save is under way, put back if it fails.
  listingBody?: string | null;
};

export function listingSetup(model: ListingComposer): ListingSetup | null {
  return (get(model, "listing") as ListingSetup | null | undefined) ?? null;
}

function sectionValue(
  model: ListingComposer,
  setup: ListingSetup,
  field: string
): string {
  if (field === setup.editorField) {
    return (model.reply ?? "").trim();
  }
  const picked = model.listingPicked?.[field] ?? [];
  const options = setup.choices[field]?.options ?? [];
  // In the options' own order, whatever order they were ticked in.
  const chosen = options.filter((option) => picked.includes(option));
  const text = (model.listingValues?.[field] ?? "").trim();
  return [chosen.join(", "), text].filter(Boolean).join("\n");
}

export function missingValues(model: ListingComposer): string[] {
  const setup = listingSetup(model);
  if (!setup) {
    return [];
  }
  return setup.fields.filter((field) => !sectionValue(model, setup, field));
}

// The post as the thread writes it: a heading per section with its
// details under it. Without an editor section, the editor's text follows.
export function assemble(model: ListingComposer): string {
  const setup = listingSetup(model);
  if (!setup) {
    return model.reply ?? "";
  }
  const sections = setup.fields.map(
    (field) => `### ${field}\n${sectionValue(model, setup, field)}`
  );
  const body = (model.reply ?? "").trim();
  if (!setup.editorField && body) {
    sections.push(body);
  }
  return sections.join("\n\n");
}
