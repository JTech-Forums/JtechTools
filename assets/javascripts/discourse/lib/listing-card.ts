// Turns a listing post's cooked HTML (a heading per section, details under
// each) into a card: the first section as its title, the short sections as
// labelled facts, longer ones full width, the pictures at the bottom.
// Anything the card doesn't recognise stays where it was, after it.

export interface ListingCardFormat {
  sections: string[];
  images?: string | null;
}

const HEADING = /^H[1-6]$/;
// Short enough to sit beside the others in the facts grid.
const SHORT_TEXT = 40;

function sectionName(element: Element, sections: string[]): string | undefined {
  if (!HEADING.test(element.tagName)) {
    return;
  }
  const text = (element.textContent ?? "")
    .replace(/[:\-–—]\s*$/, "")
    .trim()
    .toLowerCase();
  return sections.find((s) => s.toLowerCase() === text);
}

function div(className: string, children: Node[] = []): HTMLDivElement {
  const el = document.createElement("div");
  el.className = className;
  children.forEach((child) => el.appendChild(child));
  return el;
}

export function buildListingCard(
  cooked: HTMLElement,
  format: ListingCardFormat
): boolean {
  if (cooked.querySelector(".listing-card")) {
    return true;
  }

  const found = new Map<string, Node[]>();
  let current: string | undefined;
  const headings: Element[] = [];
  Array.from(cooked.children).forEach((child) => {
    const name = sectionName(child, format.sections);
    if (name && !found.has(name)) {
      current = name;
      found.set(name, []);
      headings.push(child);
    } else if (current) {
      found.get(current)?.push(child);
    }
  });

  // Not a listing (a comment from before the topic was added, a staff
  // note): leave it as a normal post.
  if (found.size < 2) {
    return false;
  }

  const [titleName, ...rest] = format.sections.filter((s) => found.has(s));
  const card = div("listing-card");

  const title = div("listing-card__title", found.get(titleName) ?? []);
  card.appendChild(title);

  const facts = div("listing-card__facts");
  let pictures: HTMLDivElement | undefined;
  rest.forEach((name) => {
    const nodes = found.get(name) ?? [];
    const label = div("listing-card__label");
    label.textContent = name.toLowerCase();
    const section = div("listing-card__fact", [
      label,
      div("listing-card__value", nodes),
    ]);
    if (name === format.images) {
      section.classList.add("listing-card__fact--pictures");
      pictures = section;
      return;
    }
    const text = nodes.map((n) => n.textContent ?? "").join(" ");
    if (nodes.length > 1 || text.trim().length > SHORT_TEXT) {
      section.classList.add("listing-card__fact--wide");
    }
    facts.appendChild(section);
  });
  card.appendChild(facts);
  if (pictures) {
    card.appendChild(pictures);
  }

  headings.forEach((h) => h.remove());
  cooked.insertBefore(card, cooked.firstChild);
  return true;
}
