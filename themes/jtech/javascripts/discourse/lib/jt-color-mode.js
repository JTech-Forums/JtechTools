import { settings } from "virtual:theme";

// The header's and command menu's light/dark switch (setting
// color_mode_toggle). It stands in for core's header colour selector, which
// jt-header.scss hides so there's only one.
export function colorToggleAvailable(interfaceColor) {
  return settings.color_mode_toggle && interfaceColor?.selectorAvailable;
}

// Flips what's on screen. Landing on the mode the device asks for goes back to
// "follow the device", so one click is never a permanent override.
export function toggleColorMode(interfaceColor) {
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
