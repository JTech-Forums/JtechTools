import Component from "@glimmer/component";
import { action } from "@ember/object";
import { themePrefix } from "virtual:theme";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import postActionFeedback from "discourse/lib/post-action-feedback";
import { clipboardCopyAsync } from "discourse/lib/utilities";
import type Post from "discourse/models/post";
import DButton from "discourse/ui-kit/d-button";

interface JtCopyPostSignature {
  Args: {
    post: Post;
    showLabel?: boolean;
  };
  Element: HTMLButtonElement | HTMLAnchorElement;
}

const ACTION_CLASS = "post-action-menu__jt-copy-post";

// Copies a post's Markdown, with the alert and tick core shows when it copies
// a post's link. The Markdown is only fetched on click (core's /posts/:id/raw,
// which checks the reader may see the post), so posts load nothing extra.
// Safari only allows a clipboard write inside the click, which is why the
// fetch goes through clipboardCopyAsync rather than being awaited first.
export default class JtCopyPost extends Component<JtCopyPostSignature> {
  @action
  copy() {
    const { post } = this.args;
    let failure: unknown;
    postActionFeedback({
      postId: post.id,
      actionClass: ACTION_CLASS,
      messageKey: themePrefix("jt.copy_post.copied"),
      actionCallback: () =>
        clipboardCopyAsync(() =>
          ajax(`/posts/${post.id}/raw`, { dataType: "text" }).then(
            (raw: string) => new Blob([raw], { type: "text/plain" }),
            (error: unknown) => {
              failure = error;
              throw error;
            }
          )
        ),
      errorCallback: () => {
        if (failure) {
          popupAjaxError(failure);
        }
      },
    });
  }

  <template>
    <DButton
      class={{ACTION_CLASS}}
      ...attributes
      @action={{this.copy}}
      @ariaLabel={{themePrefix "jt.copy_post.title"}}
      @icon="copy"
      @label={{if @showLabel (themePrefix "jt.copy_post.label")}}
      @title={{themePrefix "jt.copy_post.title"}}
    />
  </template>
}
