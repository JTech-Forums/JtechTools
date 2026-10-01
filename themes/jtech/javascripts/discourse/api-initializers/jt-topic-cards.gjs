import { settings } from "virtual:theme";
import HeaderTopicCell from "discourse/components/topic-list/header/topic-cell";
import { apiInitializer } from "discourse/lib/api";
import JtTopicCard from "../components/jt-topic-card";

// Discovery lists (latest/new/top/category/tag, group + user activity) become
// cards. Suggested/related lists at the foot of a topic stay compact rows.
const CARD_CONTEXTS = ["discovery", "group-activity", "user-activity"];

const isCardContext = ({ listContext, category }) =>
  settings.topic_cards &&
  CARD_CONTEXTS.includes(listContext) &&
  !category?.doc_index_topic_id;

const CardCell = <template>
  <JtTopicCard
    @bulkSelectEnabled={{@bulkSelectEnabled}}
    @hideCategory={{@hideCategory}}
    @isSelected={{@isSelected}}
    @onBulkSelectToggle={{@onBulkSelectToggle}}
    @topic={{@topic}}
  />
</template>;

export default apiInitializer((api) => {
  api.registerValueTransformer("topic-list-class", ({ value, context }) => {
    if (isCardContext(context)) {
      value.push("jt-cards");
    }
    return value;
  });

  api.registerValueTransformer("topic-list-columns", ({ value, context }) => {
    if (!isCardContext(context)) {
      return value;
    }
    // bulk-select stays: core's checkbox cell + header select-all keep working
    for (const name of [
      "topic",
      "posters",
      "replies",
      "likes",
      "op-likes",
      "views",
      "activity",
    ]) {
      value.delete(name);
    }
    value.add("jt-card", { header: HeaderTopicCell, item: CardCell });
    return value;
  });

  api.registerValueTransformer(
    "topic-list-item-mobile-layout",
    ({ value, context }) => (isCardContext(context) ? false : value)
  );

  // Click anywhere on the card opens the topic; real links/buttons inside keep
  // their own behaviour. Modifier keys and middle-click open a new tab.
  api.registerBehaviorTransformer("topic-list-item-click", ({ context, next }) => {
    const { event, topic, listContext } = context;
    if (!isCardContext({ listContext, category: topic?.category })) {
      return next();
    }
    if (
      (event.target.closest("a, button, input, label") &&
        !event.target.closest(".topic-excerpt")) ||
      event.target.closest(".topic-excerpt-more")
    ) {
      return next();
    }

    const link = event.target
      .closest(".topic-list-item")
      ?.querySelector("a.raw-topic-link");
    if (!link) {
      return next();
    }
    event.preventDefault();
    event.stopPropagation();

    if (event.button === 1) {
      window.open(link.href, "_blank", "noopener,noreferrer");
      return;
    }
    link.dispatchEvent(
      new MouseEvent("click", {
        ctrlKey: event.ctrlKey,
        metaKey: event.metaKey,
        shiftKey: event.shiftKey,
        button: event.button,
        bubbles: true,
        cancelable: true,
      })
    );
  });
});
