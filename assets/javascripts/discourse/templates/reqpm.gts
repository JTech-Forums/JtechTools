import type { TemplateOnlyComponent } from "@ember/component/template-only";
import RouteTemplate from "ember-route-template";
import ReqpmHub from "../components/reqpm-hub";
import type ReqpmController from "../controllers/reqpm";

const ReqpmTemplate: TemplateOnlyComponent<{
  Args: { controller: ReqpmController };
}> = <template>
  <ReqpmHub
    @onTabChange={{@controller.changeTab}}
    @tab={{@controller.tab}}
    @user={{@controller.user}}
  />
</template>;

export default RouteTemplate(ReqpmTemplate);
