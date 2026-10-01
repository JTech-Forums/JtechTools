import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import { type TrustedHTML, trustHTML } from "@ember/template";
import type AppEventsService from "discourse/services/app-events";

interface JtReadingProgressSignature {
  Args: Record<string, never>;
}

// What core's topic controller sends with topic:current-post-scrolled.
interface PostScrolledEvent {
  postIndex: number;
  percent: number;
}

// Hairline under the header showing how far through the topic you are. Driven
// by the same event as core's own progress widget, so it measures the whole
// topic (by post), not just the posts loaded so far.
export default class JtReadingProgress extends Component<JtReadingProgressSignature> {
  @service declare appEvents: AppEventsService;

  @tracked percent = 0;

  constructor(owner: Owner, args: JtReadingProgressSignature["Args"]) {
    super(owner, args);
    this.appEvents.on("topic:current-post-scrolled", this, this.onScrolled);
  }

  willDestroy() {
    super.willDestroy();
    this.appEvents.off("topic:current-post-scrolled", this, this.onScrolled);
  }

  get style(): TrustedHTML {
    return trustHTML(`--jt-progress: ${this.percent}`);
  }

  onScrolled(event: PostScrolledEvent) {
    this.percent = Math.max(0, Math.min(1, event?.percent || 0));
  }

  <template>
    <div aria-hidden="true" class="jt-progress" style={{this.style}}></div>
  </template>
}
