import { i18n } from "discourse-i18n";

// Options for the trust-level audience dropdowns. `includeAll` adds the
// "Everyone" (4) and "Up to regulars" (3) choices used by the prompt
// caps; the first-post checklist omits them since it only gates TL0-2.
export function trustLevelOptions(includeAll = true) {
  const options = [];
  if (includeAll) {
    options.push({ id: "4", name: i18n("discourse_mod_categories.audience.all") });
  }
  options.push(
    { id: "0", name: i18n("discourse_mod_categories.audience.tl0") },
    { id: "1", name: i18n("discourse_mod_categories.audience.tl1") },
    { id: "2", name: i18n("discourse_mod_categories.audience.tl2") }
  );
  if (includeAll) {
    options.push({ id: "3", name: i18n("discourse_mod_categories.audience.tl3") });
  }
  return options;
}
