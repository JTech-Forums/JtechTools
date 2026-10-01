import { settings } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";

// Marks links in posts that leave the forum (a small ↗ via CSS). Hosts are
// matched exactly: subdomains like market.jtechforums.org are other sites.
const SKIP =
  ".onebox, aside.onebox, .lightbox-wrapper, .mention, .mention-group, " +
  ".hashtag-cooked, .attachment, .btn, [data-wrap='ghbtn'], .quote .title, " +
  ".footnote-ref, .footnote-backref";

export default apiInitializer((api) => {
  if (!settings.external_link_icon) {
    return;
  }

  const internal = new Set(
    [window.location.hostname, ...settings.internal_hosts.split("|")]
      .map((h) => h.trim().toLowerCase())
      .filter(Boolean)
  );

  api.decorateCookedElement(
    (element) => {
      for (const a of element.querySelectorAll("a[href]")) {
        if (a.closest(SKIP) || !a.textContent.trim()) {
          continue;
        }
        // image-only links (no text besides the image)
        if (a.querySelector("img") && !a.innerText.trim()) {
          continue;
        }
        let url;
        try {
          url = new URL(a.getAttribute("href"), window.location.href);
        } catch {
          continue;
        }
        if (
          /^https?:$/.test(url.protocol) &&
          !internal.has(url.hostname.toLowerCase())
        ) {
          a.classList.add("jt-external");
        }
      }
    },
    { id: "jt-external-links" }
  );
});
