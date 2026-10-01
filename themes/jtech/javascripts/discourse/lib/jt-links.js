// Same-site links that aren't forum pages (the landing site at /home, the
// plugin's /dumb, …) need a real page load. Core's click interceptor sends
// every same-site link through the forum's router, which shows its 404 page
// for those. A link with data-auto-route is left to the browser.
export function needsFullPageLoad(router, url) {
  if (!url) {
    return false;
  }

  let parsed;
  try {
    parsed = new URL(url, window.location.href);
  } catch {
    return false;
  }
  if (parsed.origin !== window.location.origin) {
    return false; // another site: the browser opens it anyway
  }

  try {
    const route = router.recognize(parsed.pathname + parsed.search);
    return !route || route.name === "unknown";
  } catch {
    return true;
  }
}
