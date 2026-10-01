import { settings } from "virtual:theme";
import JtFooter from "../../components/jt-footer";

// Core's showFooter already waits for infinite scroll to reach the end.
const JtFooterConnector = <template>
  {{#if settings.footer_enabled}}
    {{#if @outletArgs.showFooter}}
      <JtFooter />
    {{/if}}
  {{/if}}
</template>;

export default JtFooterConnector;
