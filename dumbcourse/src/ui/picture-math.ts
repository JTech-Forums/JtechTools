// Sizes and scroll positions for the picture viewer. No DOM here, so it can
// be tested without a browser.

const ZOOMS = [1, 2, 3];

// OK steps through fit, 2x and 3x, then back to fit.
export function nextZoom(zoom: number): number {
  const i = ZOOMS.indexOf(zoom);
  return ZOOMS[(i + 1) % ZOOMS.length];
}

// The picture fitted inside the stage. A small picture keeps its own size
// rather than being blown up; zooming enlarges it.
export function fitSize(
  naturalW: number,
  naturalH: number,
  stageW: number,
  stageH: number
): { w: number; h: number } {
  if (!(naturalW > 0 && naturalH > 0 && stageW > 0 && stageH > 0))
    return { w: 0, h: 0 };
  const scale = Math.min(stageW / naturalW, stageH / naturalH, 1);
  return {
    w: Math.max(1, Math.round(naturalW * scale)),
    h: Math.max(1, Math.round(naturalH * scale)),
  };
}

// Space before the picture that centres it while it's smaller than the stage.
export function centring(size: number, stage: number): number {
  return Math.max(0, Math.round((stage - size) / 2));
}

// The scroll position that keeps the point in the middle of the stage in the
// middle when the picture changes size (zooming in or out), along one axis.
export function keepCentre(
  scroll: number,
  stage: number,
  oldSize: number,
  oldOffset: number,
  newSize: number,
  newOffset: number
): number {
  if (!(oldSize > 0)) return 0;
  const middle = (scroll + stage / 2 - oldOffset) / oldSize;
  const target = Math.round(middle * newSize + newOffset - stage / 2);
  const max = Math.max(0, newOffset + newSize - stage);
  return Math.max(0, Math.min(target, max));
}

// How far one press of the D-pad moves a zoomed picture.
export function panStep(stage: number): number {
  return Math.max(16, Math.round(stage * 0.4));
}
