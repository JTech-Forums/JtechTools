import { settings } from "virtual:theme";
import JtReadingProgress from "../../components/jt-reading-progress";

const JtReadingProgressConnector = <template>
  {{#if settings.reading_progress}}
    <JtReadingProgress />
  {{/if}}
</template>;

export default JtReadingProgressConnector;
