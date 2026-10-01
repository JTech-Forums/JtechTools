import { settings } from "virtual:theme";
import JtJumpButtons from "../../components/jt-jump-buttons";

const JtTimelineJump = <template>
  {{#if settings.topic_jump_buttons}}
    <JtJumpButtons @className="--timeline" @topic={{@outletArgs.model}} />
  {{/if}}
</template>;

export default JtTimelineJump;
