// Runs inline in <head>, before the page paints, so the saved theme and
// text size apply without a flash. Kept tiny and dependency-free; the
// server inlines the built file and allows it by its CSP hash.

(function () {
  const root = document.documentElement;
  let prefs: {
    theme?: string;
    textSize?: number;
    density?: string;
    avatars?: boolean;
    softkeys?: string;
    keypad?: boolean;
  } = {};
  try {
    prefs = JSON.parse(window.localStorage.getItem("dc:prefs") || "{}") || {};
  } catch {
    prefs = {};
  }
  let light = prefs.theme === "light";
  if (!prefs.theme || prefs.theme === "auto") {
    const fallback = root.getAttribute("data-default-theme");
    if (fallback === "light") light = true;
    else if (fallback !== "dark") {
      try {
        light = !!(
          window.matchMedia &&
          window.matchMedia("(prefers-color-scheme: light)").matches
        );
      } catch {
        light = false;
      }
    }
  }
  const classes = [light ? "light" : "dark"];
  if (prefs.density === "compact") classes.push("compact");
  if (prefs.avatars === false) classes.push("no-avatars");
  // Same rule as softkeysVisible() in prefs.ts.
  const w = window.innerWidth || root.clientWidth;
  const s = window.screen;
  const shape =
    s && s.width && s.height
      ? Math.min(s.width, s.height) / Math.max(s.width, s.height)
      : 0;
  const small = w <= 480 && (prefs.keypad === true || !shape || shape >= 0.65);
  if (prefs.softkeys === "on" || (prefs.softkeys !== "off" && small))
    classes.push("with-softkeys");
  root.className = classes.join(" ");
  if (prefs.textSize && prefs.textSize >= 50 && prefs.textSize <= 200)
    root.style.fontSize = (15 * prefs.textSize) / 100 + "px";
})();
