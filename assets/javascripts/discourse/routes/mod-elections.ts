import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

// /elections — data loads inside the component, so switching to a past
// election (?id=) doesn't reload the route.
export default class ModElectionsRoute extends DiscourseRoute {
  queryParams = {
    id: { replace: true },
  };

  titleToken(): string {
    return i18n("mod_elections.title");
  }
}
