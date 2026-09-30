import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";

// /u/:username/preferences/reqpm — your own contact card, in settings.
export default class PreferencesReqpmRoute extends RestrictedUserRoute {
  @service reqpm;
  @service router;

  showFooter = true;

  setupController(controller, user) {
    if (!this.reqpm.available) {
      return this.router.transitionTo("preferences.account", user);
    }
    controller.set("model", user);
  }
}
