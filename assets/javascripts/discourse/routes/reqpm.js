import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

// /reqpm — the hub page. Data loads inside the component so it can refresh
// live when a request or share arrives.
export default class ReqpmRoute extends DiscourseRoute {
  queryParams = {
    tab: { replace: true },
    user: { replace: true },
  };

  titleToken() {
    return i18n("reqpm.title");
  }
}
