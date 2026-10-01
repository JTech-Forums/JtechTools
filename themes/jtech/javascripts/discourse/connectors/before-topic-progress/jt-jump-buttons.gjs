import { settings } from "virtual:theme";
import JtJumpButtons from "../../components/jt-jump-buttons";

const JtProgressJump = <template>
  {{#if settings.topic_jump_buttons}}
    <JtJumpButtons @className="--progress" @topic={{@outletArgs.model}} />
  {{/if}}
</template>;

export default JtProgressJump;
