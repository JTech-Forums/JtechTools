import RouteTemplate from "ember-route-template";
import ReqpmHub from "../components/reqpm-hub";

export default RouteTemplate(
  <template>
    <ReqpmHub
      @tab={{@controller.tab}}
      @user={{@controller.user}}
      @onTabChange={{@controller.changeTab}}
    />
  </template>
);
