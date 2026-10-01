import { settings } from "virtual:theme";
import JtBackToTop from "../../components/jt-back-to-top";

const BackToTop = <template>
  {{#if settings.back_to_top}}
    <JtBackToTop />
  {{/if}}
</template>;

export default BackToTop;
