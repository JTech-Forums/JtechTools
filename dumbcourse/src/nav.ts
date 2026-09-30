// D-pad navigation. Up/Down walk the focusable things on screen in reading
// order; Left/Right move inside a row (a `[data-row]` container, like the
// top bar or a row of buttons) and switch tabs on screens with a tab strip.
// Long content is readable: if the focused thing continues past the edge
// of the screen, Down scrolls it instead of jumping away.

import { closest, matches } from "./compat.ts";
import {
  $,
  $$,
  bottomBarHeight,
  isVisible,
  revealElement,
  topbarHeight,
  viewportHeight,
} from "./dom.ts";

const FOCUSABLE =
  'a[href], button, input, textarea, select, [tabindex], summary, [contenteditable="true"]';

// The innermost open layer (dialog, sheet, drawer) owns the keys; with no
// layer open, the page (top bar + content) does.
export function activeScope(): HTMLElement {
  const layers = $$(".layer.open");
  if (layers.length) return layers[layers.length - 1];
  return document.body;
}

function usable(el: HTMLElement): boolean {
  if ((el as HTMLButtonElement).disabled) return false;
  const tab = el.getAttribute("tabindex");
  if (tab !== null && parseInt(tab, 10) < 0) return false;
  if (el.tagName === "INPUT" && (el as HTMLInputElement).type === "hidden")
    return false;
  if (closest(el, "[hidden], .layer:not(.open), [data-nofocus]")) return false;
  return isVisible(el);
}

export function focusables(scope: HTMLElement = activeScope()): HTMLElement[] {
  let list = $$(FOCUSABLE, scope).filter(usable);
  if (scope === document.body) {
    // Layers that are not open never take focus.
    list = list.filter((el) => !closest(el, ".layer"));
  }
  return list;
}

function rowOf(el: HTMLElement): HTMLElement | null {
  return closest(el, "[data-row], [data-grid]");
}

// In a grid (emoji pickers), Up/Down move by a whole row of cells.
function gridStep(
  el: HTMLElement,
  list: HTMLElement[],
  direction: "up" | "down"
): HTMLElement | null | undefined {
  const grid = closest(el, "[data-grid]");
  if (!grid) return undefined;
  const cells = list.filter((x) => grid.contains(x));
  const idx = cells.indexOf(el);
  let cols = 0;
  const top = cells.length ? cells[0].offsetTop : 0;
  for (let i = 0; i < cells.length && cells[i].offsetTop === top; i++) cols++;
  cols = Math.max(1, cols);
  const target = cells[direction === "down" ? idx + cols : idx - cols];
  if (target) return target;
  // Past the grid's first/last row: fall through to normal movement, but
  // stay in the grid if the last row is only partly filled.
  if (
    direction === "down" &&
    Math.floor(idx / cols) < Math.floor((cells.length - 1) / cols)
  ) {
    return cells[cells.length - 1];
  }
  return null;
}

export function focus(el: HTMLElement | null, reveal = true): boolean {
  if (!el) return false;
  try {
    el.focus();
  } catch {
    return false;
  }
  if (reveal) revealElement(el, closest(el, ".layer .scroll"));
  return document.activeElement === el;
}

function current(): HTMLElement | null {
  const el = document.activeElement as HTMLElement | null;
  if (!el || el === document.body || el === document.documentElement)
    return null;
  return el;
}

// When nothing is focused, start from the first item visible on screen
// rather than the top of the page.
function firstOnScreen(list: HTMLElement[]): HTMLElement | null {
  const top = topbarHeight();
  for (let i = 0; i < list.length; i++) {
    const r = list[i].getBoundingClientRect();
    if (r.bottom > top && r.top < viewportHeight()) return list[i];
  }
  return list[0] || null;
}

// Scroll step used for reading long content.
function step(): number {
  return Math.max(
    60,
    Math.round((viewportHeight() - topbarHeight() - bottomBarHeight()) * 0.7)
  );
}

function inLayerScroll(el: HTMLElement): HTMLElement | null {
  return closest(el, ".layer .scroll");
}

export function move(direction: "up" | "down"): boolean {
  const scope = activeScope();
  const list = focusables(scope);
  const el = current();
  const idx = el ? list.indexOf(el) : -1;

  if (idx < 0) {
    return focus(firstOnScreen(list));
  }

  // Reading a long item: scroll within it first. The item is the focused
  // element — or the post it sits in, so a poll or a button inside a long
  // post doesn't let focus skip the rest of the post's text.
  if (!inLayerScroll(el as HTMLElement) && scope === document.body) {
    const item = closest(el, "[data-read], .post") || (el as HTMLElement);
    const rect = item.getBoundingClientRect();
    const topLimit = topbarHeight();
    const bottomLimit = viewportHeight() - bottomBarHeight();
    const outside = (x: HTMLElement | undefined) => !x || !item.contains(x);
    if (direction === "down" && rect.bottom > bottomLimit + 8) {
      const next = list[idx + 1];
      // …unless the next stop is already on screen, or still inside it.
      if (
        outside(next) &&
        (!next || next.getBoundingClientRect().top > bottomLimit - 24)
      ) {
        window.scrollBy(0, Math.min(step(), rect.bottom - bottomLimit + 8));
        return true;
      }
    }
    if (direction === "up" && rect.top < topLimit - 8) {
      const prev = list[idx - 1];
      if (
        outside(prev) &&
        (!prev || prev.getBoundingClientRect().bottom < topLimit + 24)
      ) {
        window.scrollBy(0, -Math.min(step(), topLimit - rect.top + 8));
        return true;
      }
    }
  }

  const inGrid = gridStep(el as HTMLElement, list, direction);
  if (inGrid) return focus(inGrid);

  // Leave a row as a whole: Down from any button in a row goes past the row.
  const row = rowOf(el as HTMLElement);
  let target: HTMLElement | null = null;
  if (direction === "down") {
    for (let i = idx + 1; i < list.length; i++) {
      if (!row || !row.contains(list[i])) {
        target = list[i];
        break;
      }
    }
  } else {
    for (let i = idx - 1; i >= 0; i--) {
      if (!row || !row.contains(list[i])) {
        target = list[i];
        // Entering a row from below lands on its first item.
        const targetRow = rowOf(target);
        if (targetRow) {
          const firstInRow = list.filter((x) => targetRow.contains(x))[0];
          const remembered = targetRow.getAttribute("data-last")
            ? $(
                `[data-key="${targetRow.getAttribute("data-last")}"]`,
                targetRow
              )
            : null;
          target =
            (remembered && usable(remembered) ? remembered : firstInRow) ||
            target;
        }
        break;
      }
    }
  }
  if (!target) {
    // At the very end: let the view load more, or scroll to the bottom.
    if (direction === "down") {
      const ev = document.createEvent("Event");
      ev.initEvent("dc:end", true, true);
      (el as HTMLElement).dispatchEvent(ev);
      window.scrollBy(0, step());
    } else {
      window.scrollTo(0, 0);
    }
    return true;
  }
  // Never jump over more than a screenful of unseen content: scroll a step
  // towards the next stop, and focus it once it's on screen.
  if (scope === document.body && !inLayerScroll(target)) {
    const r = target.getBoundingClientRect();
    const topLimit = topbarHeight();
    const bottomLimit = viewportHeight() - bottomBarHeight();
    if (direction === "down" && r.top > bottomLimit + step() * 0.5) {
      window.scrollBy(0, step());
      return true;
    }
    if (direction === "up" && r.bottom < topLimit - step() * 0.5) {
      window.scrollBy(0, -step());
      return true;
    }
  }
  return focus(target);
}

export function moveInRow(direction: "left" | "right"): boolean {
  const el = current();
  if (!el) return false;
  const row = rowOf(el);
  if (!row) return false;
  const items = focusables(activeScope()).filter((x) => row.contains(x));
  const idx = items.indexOf(el);
  const next = items[direction === "right" ? idx + 1 : idx - 1];
  if (!next) return true; // stay put at the row's edges
  const key = next.getAttribute("data-key");
  if (key) row.setAttribute("data-last", key);
  focus(next, false);
  // Keep a horizontally scrolling row showing the focused item.
  const box = next.getBoundingClientRect();
  const rowBox = row.getBoundingClientRect();
  if (box.right > rowBox.right) row.scrollLeft += box.right - rowBox.right + 8;
  else if (box.left < rowBox.left) row.scrollLeft -= rowBox.left - box.left + 8;
  return true;
}

// Moves between tabs of the screen's tab strip.
export function switchTab(direction: "left" | "right"): boolean {
  const strip = $("[data-tabs]");
  if (!strip || activeScope() !== document.body) return false;
  const tabs = $$<HTMLElement>("[data-tab]", strip);
  let idx = -1;
  for (let i = 0; i < tabs.length; i++)
    if (tabs[i].classList.contains("on")) idx = i;
  const next = tabs[direction === "right" ? idx + 1 : idx - 1];
  if (!next) return true;
  next.click();
  return true;
}

export function focusFirst(
  scope: HTMLElement = activeScope(),
  selector?: string
): boolean {
  const list = focusables(scope);
  if (selector) {
    for (let i = 0; i < list.length; i++)
      if (matches(list[i], selector)) return focus(list[i]);
  }
  return focus(list[0] || null);
}

// Focus the first thing in the page content (skipping the top bar).
export function focusContent(selector?: string): void {
  requestAnimationFrame(() => {
    const app = document.getElementById("app");
    if (!app) return;
    if (activeScope() !== document.body) return;
    const list = focusables(document.body).filter(
      (el) => app.contains(el) && !closest(el, "[data-tabs]")
    );
    let target: HTMLElement | null = null;
    if (selector) {
      for (let i = 0; i < list.length; i++)
        if (matches(list[i], selector)) target = target || list[i];
    }
    focus(target || list[0] || null);
  });
}

export function focusByKey(key: string): boolean {
  const el = $(`[data-key="${key.replace(/"/g, "")}"]`);
  if (el && usable(el)) return focus(el);
  return false;
}

export function currentKey(): string {
  const el = current();
  if (!el) return "";
  const keyed = closest(el, "[data-key]");
  return keyed ? keyed.getAttribute("data-key") || "" : "";
}
