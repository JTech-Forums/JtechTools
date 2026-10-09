import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class ModElectionsController extends Controller {
  @tracked id: string | null = null;

  queryParams = ["id"];
}
