# frozen_string_literal: true

module DiscourseMiniMod
  # Hides the close/reopen toggle button on the topic admin menu when a reopen
  # restriction is active and the topic is already closed.
  #
  # The Guardian-level can_close_topic? override blocks the action server-side
  # (TopicsController#status -> ensure_can_close_topic!), but the button
  # visibility is decided independently by include_can_close_topic? on this
  # serializer (which core aliases to can_perform_action_available_to_group_moderators?).
  # Without this override the button stays visible and clicking it surfaces a
  # permission error.
  #
  # Two restrictions are mirrored here:
  #   * mini_mod_can_reopen_topics — scoped to category group moderators
  #   * tl4_can_reopen_topics      — scoped to trust level 4 users site-wide
  #
  # Both branches only fire when the topic is already closed, so the close
  # button on open topics is unaffected. Every other admin action (archive,
  # pin, split/merge, etc.) is also unaffected.
  module TopicViewDetailsSerializerExtension
    def include_can_close_topic?
      topic = object.topic
      return super if !SiteSetting.mini_mod_enabled
      return super if !topic.closed?
      return super if scope.user.blank? || scope.is_staff?

      if !SiteSetting.tl4_can_reopen_topics && scope.user.has_trust_level?(TrustLevel[4])
        return false
      end

      if !SiteSetting.mini_mod_can_reopen_topics && topic.category.present? &&
           scope.is_category_group_moderator?(topic.category)
        return false
      end

      super
    end
  end
end
