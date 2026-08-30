import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

// Full-page conversation. Like core Chat's route: on desktop, when the drawer
// is the preferred mode and this is an in-app transition (not a hard load or
// an explicit "open in full page"), open the drawer instead of navigating.
export default class DisteleplusRoute extends DiscourseRoute {
  @service disteleplus;

  titleToken() {
    return i18n("disteleplus.title");
  }

  beforeModel(transition) {
    this.disteleplus.storeAppURL();
    // Deep link (#m<id>) from a notification or a copied message link. The
    // Ember router drops the hash, so read it off the transition/URL here
    // and stash it for whichever surface (drawer or full page) opens.
    const hash =
      transition.intent?.url?.match(/#m(\d+)/) ||
      window.location.hash.match(/^#m(\d+)$/);
    if (hash) {
      this.disteleplus.requestJump(Number(hash[1]));
    }
    const fullPageReload = !transition.from;
    if (this.disteleplus.isDrawerPreferred && !fullPageReload) {
      transition.abort();
      this.disteleplus.openDrawer();
      return;
    }
    this.disteleplus.closeDrawer();
  }

  model() {
    return this.disteleplus.ensureLoaded();
  }

  activate() {
    super.activate(...arguments);
    document.documentElement.classList.add("has-full-page-disteleplus");
    document.body.classList.add("has-full-page-disteleplus");
  }

  deactivate() {
    super.deactivate(...arguments);
    document.documentElement.classList.remove("has-full-page-disteleplus");
    document.body.classList.remove("has-full-page-disteleplus");
  }
}
