import RouteTemplate from "ember-route-template";
import ReqpmPreferences from "../../components/reqpm-preferences";

export default RouteTemplate(
  <template>
    <ReqpmPreferences
      @user={{@controller.model}}
      @showHeading={{true}}
      @showHubLink={{true}}
    />
  </template>
);
