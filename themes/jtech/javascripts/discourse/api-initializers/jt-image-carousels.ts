import { settings } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import setupImageGridCarousel from "discourse/lib/image-grid-carousel";

// Posts written with the Post Image Carousel component's [wrap=Carousel]
// (setting image_carousels): their pictures become Discourse's own carousel,
// the one [grid mode=carousel] makes. The pictures are gathered into such a
// grid where the first one was and handed to core; any text in the wrap
// stays. Its autoplay, loop and thumbnail options aren't carried over.
export default apiInitializer((api) => {
  if (!settings.image_carousels) {
    return;
  }

  api.decorateCookedElement(
    (cooked: HTMLElement, helper: unknown) => {
      const wraps = cooked.querySelectorAll<HTMLElement>(
        '.d-wrap[data-wrap="Carousel" i]'
      );
      for (const wrap of wraps) {
        // a [grid mode=carousel] inside it is core's already
        if (wrap.querySelector('.d-image-grid[data-mode="carousel"]')) {
          continue;
        }
        const pictures = [
          ...new Set(
            [...wrap.querySelectorAll("img:not(.emoji)")].map(
              (img) => img.closest(".lightbox-wrapper") ?? img
            )
          ),
        ];
        if (pictures.length < 2) {
          continue;
        }
        const grid = document.createElement("div");
        grid.className = "d-image-grid";
        grid.dataset.mode = "carousel";
        pictures[0].before(grid);
        for (const picture of pictures) {
          const holder = picture.parentElement;
          grid.append(picture);
          // the paragraph (or a plain grid's column) left empty behind it
          if (
            holder &&
            holder !== wrap &&
            !holder.textContent?.trim() &&
            !holder.querySelector("img")
          ) {
            holder.remove();
          }
        }
        // a picture in a paragraph cooks to <p><div>, which the browser
        // splits into an empty <p> each side of it, and pictures on
        // consecutive lines leave their <br>s: gaps once they've moved
        for (const p of wrap.querySelectorAll(":scope > p")) {
          const empty = [...p.children].every(
            (child) => child.tagName === "BR"
          );
          if (!p.textContent?.trim() && empty) {
            p.remove();
          }
        }
        setupImageGridCarousel(grid, helper);
      }
    },
    { id: "jt-image-carousels" }
  );
});
