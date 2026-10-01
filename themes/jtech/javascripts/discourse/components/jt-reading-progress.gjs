import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";

// Hairline under the header showing how far through the topic you are. Driven
// by the same event as core's own progress widget, so it measures the whole
// topic (by post), not just the posts loaded so far.
export default class JtReadingProgress extends Component {
  @service appEvents;

  @tracked percent = 0;

  constructor() {
    super(...arguments);
    this.appEvents.on("topic:current-post-scrolled", this, this.onScrolled);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("topic:current-post-scrolled", this, this.onScrolled);
  }

  get style() {
    return trustHTML(`--jt-progress: ${this.percent}`);
  }

  onScrolled(event) {
    this.percent = Math.max(0, Math.min(1, event?.percent || 0));
  }

  <template>
    <div aria-hidden="true" class="jt-progress" style={{this.style}}></div>
  </template>
}
