import { apiInitializer } from "discourse/lib/api";

// jt-header.scss hides the ☰ wherever the sidebar docks. Someone who had
// collapsed the sidebar before would then have no way to bring it back, so
// forget core's remembered "hidden" state and show it. Runs on the first
// page change: reading site.desktopView during initialization is deprecated.
export default apiInitializer((api) => {
  let done = false;

  api.onPageChange(() => {
    if (done) {
      return;
    }
    done = true;

    const site = api.container.lookup("service:site");
    const keyValueStore = api.container.lookup("service:key-value-store");
    if (!site.desktopView || !keyValueStore.getItem("sidebar-hidden")) {
      return;
    }

    keyValueStore.removeItem("sidebar-hidden");
    if (window.matchMedia("(min-width: 48rem)").matches) {
      // Assign even though the getter now reads true: the page rendered from
      // the old value, and only setting the tracked field re-renders it.
      const application = api.container.lookup("controller:application");
      if (application) {
        application.showSidebar = true;
      }
    }
  });
});
