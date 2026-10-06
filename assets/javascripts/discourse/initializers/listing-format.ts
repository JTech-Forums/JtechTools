import type DialogService from "discourse/dialog-holder/services/dialog";
import { withPluginApi } from "discourse/lib/plugin-api";
import type Post from "discourse/models/post";
import { i18n } from "discourse-i18n";
import ListingFormatReqpmButton from "../components/listing-format-reqpm-button";
import {
  assemble,
  type ListingComposer,
  listingSetup,
  type ListingTopicFields,
  missingValues,
} from "../lib/listing-format";
import type ReqpmService from "../services/reqpm";

interface PostMenuDag {
  add(key: string, value: unknown, position?: { before?: string }): void;
  delete(key: string): void;
}

interface PostMenuContext {
  post: Post & {
    post_number: number;
    user_id: number;
    topic?: ListingTopicFields | null;
  };
  buttonKeys: Record<string, string>;
}

interface ComposerServiceWithModel {
  model?: ListingComposer | null;
}

// Listing topics (see sub_plugins/listing_format.rb): each listing gets the
// seller's REQ-PM button and loses its Reply button, and replying opens a
// form with a fixed label per section above the editor.
export default {
  name: "jtech-listing-format",

  initialize() {
    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();

      api.registerValueTransformer(
        "post-menu-buttons",
        ({
          value: dag,
          context: { post, buttonKeys },
        }: {
          value: PostMenuDag;
          context: PostMenuContext;
        }) => {
          const topic = post.topic;
          if (!topic?.listing_format_topic) {
            return;
          }
          // Only for people who have to post listings, who add one with
          // Create listing instead; staff keep Reply to answer someone.
          if (topic.listing_format_fields?.length) {
            dag.delete(buttonKeys.REPLY);
          }
          if (post.post_number === 1) {
            return;
          }
          const reqpm = api.container.lookup("service:reqpm") as
            | ReqpmService
            | undefined;
          if (
            reqpm?.available &&
            post.user_id > 0 &&
            post.user_id !== currentUser?.id
          ) {
            dag.add("listing-format-reqpm", ListingFormatReqpmButton, {
              before: buttonKeys.SHOW_MORE,
            });
          }
        }
      );

      const composerModel = (): ListingComposer | null | undefined =>
        (
          api.container.lookup("service:composer") as
            | ComposerServiceWithModel
            | undefined
        )?.model;

      api.onAppEvent("composer:opened", () => {
        const model = composerModel();
        if (!model || listingSetup(model)) {
          return;
        }
        const topic = model.topic;
        const fields = topic?.listing_format_fields;
        if (model.action !== "reply" || !fields?.length) {
          return;
        }
        model.set("listingValues", {});
        model.set("listingPicked", {});
        model.set("listingBody", null);
        model.set("listing", {
          fields,
          choices: topic?.listing_format_choices ?? {},
          editorField: topic?.listing_format_editor_field ?? null,
        });
      });

      // Core runs this just before saving, so the form's lines go to the
      // top of the post here. If the save fails, the editor gets its own
      // text back, so a second try doesn't repeat the lines.
      api.registerValueTransformer(
        "composer-service-cannot-submit-post",
        ({
          value,
          context: { model },
        }: {
          value: boolean;
          context: { model?: ListingComposer | null };
        }) => {
          if (!model || !listingSetup(model) || model.listingBody != null) {
            return value;
          }
          const missing = missingValues(model);
          if (missing.length) {
            (api.container.lookup("service:dialog") as DialogService).alert(
              i18n("listing_format.composer.missing", {
                fields: missing.join(", "),
              })
            );
            return true;
          }
          model.set("listingBody", model.reply ?? "");
          model.set("reply", assemble(model));
          if (model.cantSubmitPost) {
            model.set("reply", model.listingBody);
            model.set("listingBody", null);
            return true;
          }
          return false;
        }
      );

      api.addComposerSaveErrorCallback(() => {
        const model = composerModel();
        if (model?.listingBody != null) {
          model.set("reply", model.listingBody);
          model.set("listingBody", null);
        }
        // Not handled: core still shows the server's reason.
        return false;
      });
    });
  },
};
