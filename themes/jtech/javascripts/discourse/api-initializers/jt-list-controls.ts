import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

// The desktop list controls (jt-topic-list.scss) keep the tabs on the
// buttons' line by never letting the tabs be wider than the room beside the
// buttons. CSS can't read a sibling's width, so this keeps it in
// --jt-list-buttons on the row. The buttons change width on their own (New
// count, Dismiss, the label hiding below 66rem), hence the observer.
export default apiInitializer((api) => {
  let observed: Element | null = null;
  const observer = new ResizeObserver(([entry]) => {
    const row = entry.target.parentElement;
    row?.style.setProperty(
      "--jt-list-buttons",
      `${Math.ceil(entry.borderBoxSize[0].inlineSize)}px`
    );
  });

  api.onPageChange(() => {
    schedule("afterRender", () => {
      const buttons = document.querySelector(
        ".list-controls .navigation-container > .navigation-controls"
      );
      if (buttons === observed) {
        return;
      }
      if (observed) {
        observer.unobserve(observed);
      }
      observed = buttons;
      if (buttons) {
        observer.observe(buttons);
      }
    });
  });
});
