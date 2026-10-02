import { schedule } from "@ember/runloop";

// Core's user menu (opened from the avatar) renders over the next few frames
// after it opens; this picks one of its tabs once it's there. If the tab
// never shows up (core's menu changed shape), `onMissing` runs instead.
export function pickUserMenuTab(tab: string, onMissing?: () => void): void {
  let frames = 30;
  const pick = () => {
    const button = document.getElementById(`user-menu-button-${tab}`);
    if (button) {
      if (!button.classList.contains("active")) {
        button.click();
      }
    } else if (--frames > 0) {
      requestAnimationFrame(pick);
    } else {
      onMissing?.();
    }
  };
  schedule("afterRender", () => requestAnimationFrame(pick));
}
