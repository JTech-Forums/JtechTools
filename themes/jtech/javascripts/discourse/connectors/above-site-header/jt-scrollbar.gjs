import { settings } from "virtual:theme";
import JtScrollbar from "../../components/jt-scrollbar";

const Scrollbar = <template>
  {{#if settings.overlay_scrollbar}}
    <JtScrollbar />
  {{/if}}
</template>;

export default Scrollbar;
