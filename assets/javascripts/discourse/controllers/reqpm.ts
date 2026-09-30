import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class ReqpmController extends Controller {
  @tracked tab: string | null = null;
  @tracked user: string | null = null;

  queryParams = ["tab", "user"];

  @action
  changeTab(tab: string) {
    this.tab = tab;
    this.user = null;
  }
}
