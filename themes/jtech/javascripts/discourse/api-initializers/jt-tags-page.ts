import { apiInitializer } from "discourse/lib/api";

// The tags page (/tags) counts each tag as "x 190": core's template puts an
// x before the number. The theme's chips (jt-tags.scss) show the number alone
// in its own little pill, so the x is taken out once a count is rendered.
// Sorting reorders the rendered chips rather than redrawing them, and a chip
// already tidied is marked so it's left alone.
function tidyCounts() {
  document
    .querySelectorAll<HTMLElement>(
      ".tags-index .tag-box .tag-count:not([data-jt-tidy])"
    )
    .forEach((count) => {
      const digits = count.textContent?.replace(/\D+/g, "");
      if (digits) {
        count.textContent = Number(digits).toLocaleString();
      }
      count.dataset.jtTidy = "";
    });
}

export default apiInitializer((api) => {
  let observer: MutationObserver | undefined;

  api.onPageChange(() => {
    observer?.disconnect();
    observer = undefined;

    const page = document.querySelector(".tags-index");
    if (!page) {
      return;
    }
    tidyCounts();
    observer = new MutationObserver(tidyCounts);
    observer.observe(page, { childList: true, subtree: true });
  });
});
