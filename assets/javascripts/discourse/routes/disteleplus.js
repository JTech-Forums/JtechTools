import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DisteleplusRoute extends DiscourseRoute {
  @service disteleplus;

  model() {
    return this.disteleplus.ensureLoaded();
  }
}
