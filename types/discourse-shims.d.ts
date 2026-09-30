// Types for modules the plugin imports by their long-standing paths.
//
// Discourse moved these into `discourse/ui-kit/` and keeps the old paths
// working through runtime shims, so the plugin keeps using them (older
// supported cores only have the old paths). @discourse/types only
// describes the new locations; these declarations point the old paths at
// them. Type-only: nothing here reaches the browser.

declare module "discourse/components/d-button" {
  export { default } from "discourse/ui-kit/d-button";
}

declare module "discourse/components/d-modal" {
  export { default } from "discourse/ui-kit/d-modal";
}

declare module "discourse/components/d-toggle-switch" {
  export { default } from "discourse/ui-kit/d-toggle-switch";
}

declare module "discourse/components/conditional-loading-spinner" {
  export { default } from "discourse/ui-kit/d-conditional-loading-spinner";
}

declare module "discourse/components/emoji-picker" {
  export { default } from "discourse/components/emoji-picker/index";
}

declare module "discourse/helpers/d-icon" {
  export { default } from "discourse/ui-kit/helpers/d-icon";
}

declare module "discourse/helpers/age-with-tooltip" {
  export { default } from "discourse/ui-kit/helpers/d-age-with-tooltip";
}

declare module "discourse/helpers/avatar" {
  export { default } from "discourse/ui-kit/helpers/d-avatar";
}

// Loader-shimmed by core; not part of @discourse/types.
declare module "ember-route-template" {
  import type { ComponentLike } from "@glint/template";

  export default function RouteTemplate<T>(template: T): ComponentLike;
}

declare module "pretty-text/emoji" {
  export function emojiSearch(
    term: string,
    options?: { maxResults?: number; diversity?: number; exclude?: string[] }
  ): string[];
}
