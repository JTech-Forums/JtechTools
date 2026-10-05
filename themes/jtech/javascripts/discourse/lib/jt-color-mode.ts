import { settings } from "virtual:theme";
import type InterfaceColor from "discourse/services/interface-color";

// The header's and command menu's light/dark switch (setting
// color_mode_toggle). It stands in for core's header colour selector, which
// jt-header.scss hides so there's only one.
export function colorToggleAvailable(
  interfaceColor: InterfaceColor | undefined
): boolean {
  return settings.color_mode_toggle && !!interfaceColor?.selectorAvailable;
}

export interface JtPaletteInfo {
  id: number;
  is_dark: boolean;
}

// The scheme id in a palette stylesheet's name:
// color_definitions_<slug>_<scheme id>_<theme id>_<digest>.css
const PALETTE_ID = /_(\d+)_-?\d*_[0-9a-f]+\.css(?:\?|$)/;

// Preferences → Interface previews a palette with link#cs-preview-light /
// #cs-preview-dark in <body>, media set for the device's mode, and leaves
// them there after Save or leaving the page, until a reload. Every light/dark
// switch (core's sidebar menu, ours) only flips the head's light-scheme and
// dark-scheme links, so a dark preview, later in the page, kept it dark after
// switching to light. Each preview follows the head link of its own kind: a
// dark palette shows while the page is dark, a light one while it's light.
// Core's light preview puts the light palette in #cs-preview-dark too, so the
// kind comes from the palette, not the id.
export function alignPalettePreviews(
  palettes: JtPaletteInfo[] | null | undefined
): void {
  const light = document.querySelector<HTMLLinkElement>("link.light-scheme");
  const dark = document.querySelector<HTMLLinkElement>("link.dark-scheme");
  if (!light || !dark) {
    return;
  }
  const previews = document.querySelectorAll<HTMLLinkElement>(
    "link#cs-preview-light, link#cs-preview-dark"
  );
  for (const preview of previews) {
    const isDark = paletteIsDark(preview.href, palettes, light, dark);
    if (isDark !== undefined) {
      preview.media = isDark ? dark.media : light.media;
    }
  }
}

function paletteIsDark(
  href: string,
  palettes: JtPaletteInfo[] | null | undefined,
  light: HTMLLinkElement,
  dark: HTMLLinkElement
): boolean | undefined {
  const id = Number(href.match(PALETTE_ID)?.[1]);
  const palette = palettes?.find((p) => p.id === id);
  if (palette) {
    return palette.is_dark;
  }
  if (href === dark.href) {
    return true;
  }
  if (href === light.href) {
    return false;
  }
  return undefined;
}

// Flips what's on screen. Landing on the mode the device asks for goes back to
// "follow the device", so one click is never a permanent override.
export function toggleColorMode(interfaceColor: InterfaceColor): void {
  const systemDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  const showingDark = interfaceColor.colorModeIsDark
    ? true
    : interfaceColor.colorModeIsLight
      ? false
      : systemDark;
  const wantDark = !showingDark;

  if (wantDark === systemDark) {
    interfaceColor.useAutoMode();
  } else if (wantDark) {
    interfaceColor.forceDarkMode();
  } else {
    interfaceColor.forceLightMode();
  }
}
