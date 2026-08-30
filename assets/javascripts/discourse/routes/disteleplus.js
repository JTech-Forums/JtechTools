import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

const BODY_CLASS = "disteleplus-full-page";

export default class DisteleplusRoute extends DiscourseRoute {
  @service disteleplus;

  model() {
    return this.disteleplus.ensureLoaded();
  }

  // Like core Chat's has-full-page-chat: strip #main-outlet padding while the
  // conversation is on screen so the page can size itself to the viewport.
  activate() {
    super.activate(...arguments);
    document.body.classList.add(BODY_CLASS);
  }

  deactivate() {
    super.deactivate(...arguments);
    document.body.classList.remove(BODY_CLASS);
  }
}
