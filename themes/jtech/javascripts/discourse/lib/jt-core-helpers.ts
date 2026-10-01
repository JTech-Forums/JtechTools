import type { TrustedHTML } from "@ember/template";
import type Category from "discourse/models/category";
import { categoryLinkHTML as coreCategoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import coreDEmoji from "discourse/ui-kit/helpers/d-emoji";

// Core helpers the theme calls without their options argument. Core's
// declarations make it required; both treat it as optional.
export const categoryLinkHTML = coreCategoryLinkHTML as (
  category: Category
) => TrustedHTML;

export const dEmoji = coreDEmoji as (code: string) => TrustedHTML;
