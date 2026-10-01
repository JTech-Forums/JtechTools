// Hardware soft keys inside the native Dumbcourse wrapper app. On keypad
// phones the app draws its own soft-key bar from ours and takes the soft
// keys before the page sees them, so they can't be taught on Phone keys;
// the app detects them itself instead. It gives the page a
// `window.SoftkeyBridge`. In a normal browser this does nothing.

interface Bridge {
  isActive?: () => boolean;
  calibrate?: () => void;
}

function bridge(): Bridge | null {
  const b = (window as unknown as { SoftkeyBridge?: Bridge }).SoftkeyBridge;
  try {
    return b && typeof b.isActive === "function" && b.isActive() ? b : null;
  } catch {
    return null;
  }
}

// Whether the app is handling the soft keys on this phone right now.
export function nativeSoftkeys(): boolean {
  const b = bridge();
  return !!b && typeof b.calibrate === "function";
}

// Ask the app to detect this phone's soft keys. False when it can't.
export function detectNativeSoftkeys(): boolean {
  const b = bridge();
  if (!b || typeof b.calibrate !== "function") return false;
  try {
    b.calibrate();
    return true;
  } catch {
    return false;
  }
}
