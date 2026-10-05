// A post's pictures, full screen. A post is one D-pad stop, so they open
// from its menu: one picture goes straight to the viewer, several open a
// gallery of thumbnails first.
//
// Viewer keys: OK zooms (fit, 2x, 3x, fit), the D-pad moves a zoomed picture
// around or, at fit, goes to the previous / next picture, 4 / 6 go to the
// previous / next picture at any zoom, the right soft key saves it, Back or
// the left soft key closes. The soft-key bar says so, and the ‹ › beside the
// counter show which way there are more pictures.
//
// On a touch screen the ‹ › are tapped to go there and tapping the picture
// zooms. A touch phone has no soft-key bar, so the head then shows its own
// Save and ✕ (styles: html:not(.with-softkeys)).

import type { Picture } from "../content/cooked.ts";
import { $, $$, show, toggleClass } from "../dom.ts";
import { html, type SafeHtml } from "../html.ts";
import { keyOf } from "../keys.ts";
import { openLayer, setLayerKeys, type Layer } from "./layers.ts";
import {
  centring,
  fitSize,
  keepCentre,
  nextZoom,
  panStep,
} from "./picture-math.ts";

export function showPictures(list: Picture[]): void {
  if (!list.length) return;
  if (list.length === 1) viewPicture(list, 0);
  else pictureGallery(list);
}

export function pictureGallery(list: Picture[]): Layer {
  const layer = openLayer({
    kind: "full",
    label: "Pictures",
    className: "pictures-layer",
    body: html`<div class="pg">
      <div class="pg-head">
        <span>${list.length} pictures</span>${closeButton()}
      </div>
      <div class="pg-grid scroll" data-grid>
        ${list.map(
          (p, i) =>
            html`<button
              type="button"
              class="pg-cell"
              data-i="${i}"
              aria-label="${p.name || `Picture ${i + 1} of ${list.length}`}"
            >
              <img src="${p.src}" alt="" />
            </button>`
        )}
      </div>
    </div>`,
    softkeys: { left: "Close", center: "View", right: "" },
    focusSelector: ".pg-cell",
  });
  wireClose(layer);
  $$("[data-i]", layer.el).forEach((cell) =>
    cell.addEventListener("click", () =>
      viewPicture(list, parseInt(cell.getAttribute("data-i") || "0", 10))
    )
  );
  return layer;
}

export function viewPicture(list: Picture[], start: number): Layer {
  let index = start;
  let zoom = 1;
  let loaded = false;
  let naturalW = 0;
  let naturalH = 0;

  const onResize = (): void => {
    if (loaded) layout(false);
  };
  const layer = openLayer({
    kind: "full",
    label: "Picture",
    className: "picture-layer",
    body: html`<div class="pv">
      <div class="pv-head">
        <span class="pv-pos"
          ><button
            type="button"
            class="pv-prev"
            tabindex="-1"
            aria-label="Previous picture"
          >
            ‹</button
          ><span class="pv-count"></span
          ><button
            type="button"
            class="pv-next"
            tabindex="-1"
            aria-label="Next picture"
          >
            ›
          </button></span
        ><span class="pv-name"></span
        ><span class="pv-tools"
          ><a class="pv-save-tap" download hidden tabindex="-1">Save</a
          >${closeButton()}</span
        >
      </div>
      <div class="pv-stage" tabindex="0" data-own-arrows data-zoom="1">
        <img class="pv-img" alt="" />
        <p class="pv-msg" role="status"></p>
      </div>
      <a class="pv-save" download hidden tabindex="-1">Save</a>
    </div>`,
    softkeys: { left: "Close", center: "", right: "" },
    focusSelector: ".pv-stage",
    onClose: () => window.removeEventListener("resize", onResize),
  });
  const el = layer.el;
  const stage = $(".pv-stage", el) as HTMLElement;
  const img = $(".pv-img", el) as HTMLImageElement;
  const msg = $(".pv-msg", el) as HTMLElement;
  const head = $(".pv-head", el) as HTMLElement;
  const count = $(".pv-count", el) as HTMLElement;
  const prev = $(".pv-prev", el) as HTMLElement;
  const next = $(".pv-next", el) as HTMLElement;
  const name = $(".pv-name", el) as HTMLElement;
  const save = $(".pv-save", el) as HTMLAnchorElement;
  const saveTap = $(".pv-save-tap", el) as HTMLAnchorElement;
  wireClose(layer);

  const updateKeys = (): void => {
    setLayerKeys(layer, {
      left: "Close",
      center: loaded ? (zoom >= 3 ? "Fit" : "Zoom") : "",
      right: list[index].save ? "Save" : "",
    });
  };

  // Sizes the picture for the current zoom; keepMiddle keeps the point in
  // the middle of the screen in the middle (zooming), else it starts at the
  // top left (a new picture).
  const layout = (keepMiddle: boolean): void => {
    const sw = stage.clientWidth;
    const sh = stage.clientHeight;
    const oldW = img.offsetWidth;
    const oldH = img.offsetHeight;
    const oldL = parseInt(img.style.marginLeft || "0", 10) || 0;
    const oldT = parseInt(img.style.marginTop || "0", 10) || 0;
    const fit = fitSize(naturalW, naturalH, sw, sh);
    const w = fit.w * zoom;
    const h = fit.h * zoom;
    const left = centring(w, sw);
    const top = centring(h, sh);
    img.style.width = w + "px";
    img.style.height = h + "px";
    img.style.marginLeft = left + "px";
    img.style.marginTop = top + "px";
    stage.setAttribute("data-zoom", String(zoom));
    const x = keepMiddle
      ? keepCentre(stage.scrollLeft, sw, oldW, oldL, w, left)
      : 0;
    const y = keepMiddle
      ? keepCentre(stage.scrollTop, sh, oldH, oldT, h, top)
      : 0;
    stage.scrollLeft = x;
    stage.scrollTop = y;
  };

  const shown = (i: number): void => {
    if (i !== index || loaded) return;
    naturalW = img.naturalWidth;
    naturalH = img.naturalHeight;
    loaded = naturalW > 0;
    if (!loaded) {
      failed(i);
      return;
    }
    show(msg, false);
    img.style.visibility = "";
    layout(false);
    updateKeys();
  };

  const failed = (i: number): void => {
    if (i !== index) return;
    loaded = false;
    msg.textContent = "Couldn't load this picture.";
    show(msg, true);
    updateKeys();
  };

  const open = (i: number): void => {
    index = i;
    zoom = 1;
    loaded = false;
    const p = list[i];
    // One picture: no "1 / 1", and no arrows.
    toggleClass(head, "pv-one", list.length < 2);
    count.textContent = list.length > 1 ? `${i + 1} / ${list.length}` : "";
    show(prev, i > 0);
    show(next, i < list.length - 1);
    name.textContent = p.name;
    stage.setAttribute(
      "aria-label",
      (p.name || "Picture") +
        (list.length > 1 ? `, ${i + 1} of ${list.length}` : "")
    );
    msg.textContent = "Loading…";
    show(msg, true);
    img.style.visibility = "hidden";
    stage.setAttribute("data-zoom", "1");
    if (p.save) {
      save.setAttribute("href", p.save);
      saveTap.setAttribute("href", p.save);
      el.setAttribute("data-softright", ".pv-save");
    } else {
      save.removeAttribute("href");
      saveTap.removeAttribute("href");
      el.removeAttribute("data-softright");
    }
    saveTap.hidden = !p.save;
    img.onload = () => shown(i);
    img.onerror = () => failed(i);
    img.src = p.full;
    // Already in the cache: some engines don't fire load again.
    if (img.complete && img.naturalWidth) shown(i);
    updateKeys();
  };

  // OK (the page clicks the focused stage) and a tap both zoom.
  stage.addEventListener("click", () => {
    if (!loaded) return;
    zoom = nextZoom(zoom);
    layout(true);
    updateKeys();
  });

  // Touch: the arrows beside the counter. Focus goes back to the picture so
  // a phone with keys as well keeps working the picture with them.
  const step = (to: number): void => {
    if (to >= 0 && to < list.length && to !== index) open(to);
    stage.focus();
  };
  prev.addEventListener("click", () => step(index - 1));
  next.addEventListener("click", () => step(index + 1));

  // The stage owns its arrows (data-own-arrows): the page leaves them alone,
  // and number keys inside a layer too.
  stage.addEventListener("keydown", (e) => {
    const key = keyOf(e);
    // 4 / 6, the keypad's left / right: previous / next picture, even zoomed.
    if (key === "4" || key === "6") {
      e.preventDefault();
      if (key === "4" && index > 0) open(index - 1);
      if (key === "6" && index < list.length - 1) open(index + 1);
      return;
    }
    if (key !== "up" && key !== "down" && key !== "left" && key !== "right")
      return;
    e.preventDefault();
    if (zoom > 1) {
      if (key === "left") stage.scrollLeft -= panStep(stage.clientWidth);
      if (key === "right") stage.scrollLeft += panStep(stage.clientWidth);
      if (key === "up") stage.scrollTop -= panStep(stage.clientHeight);
      if (key === "down") stage.scrollTop += panStep(stage.clientHeight);
      return;
    }
    if (key === "left" && index > 0) open(index - 1);
    if (key === "right" && index < list.length - 1) open(index + 1);
  });

  window.addEventListener("resize", onResize);
  open(start);
  return layer;
}

// Touch screens' Close: what the Close soft key and Back do.
function closeButton(): SafeHtml {
  return html`<button
    type="button"
    class="pv-close"
    tabindex="-1"
    aria-label="Close"
  >
    ✕
  </button>`;
}

function wireClose(layer: Layer): void {
  const btn = $(".pv-close", layer.el);
  if (btn) btn.addEventListener("click", () => layer.requestClose());
}
