// The moderator-set bottom-pinned message lives on the topic as the
// `mod_topic_footer_message` custom field.
export function topicFooterMessage(topic) {
  return ((topic && topic.mod_topic_footer_message) || "").trim();
}

// Structural gate: the feature is on and this topic is one that may show
// a footer message. Evaluated by the connector's static `shouldRender`;
// it does NOT depend on the message text, which can change at runtime
// and is handled reactively inside the connector template.
export function topicFooterFeatureActive(siteSettings, topic) {
  if (!siteSettings || !siteSettings.topic_footer_message_enabled) {
    return false;
  }
  if (!topic || topic.archetype === "private_message") {
    return false;
  }
  return true;
}

// Overall visibility = structural gate AND a non-empty message.
export function shouldRenderTopicFooterMessage(siteSettings, topic) {
  return (
    topicFooterFeatureActive(siteSettings, topic) &&
    topicFooterMessage(topic).length > 0
  );
}
