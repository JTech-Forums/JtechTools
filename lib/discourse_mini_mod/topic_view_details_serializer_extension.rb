# frozen_string_literal: true

module DiscourseMiniMod
  # Hides the close/reopen button on a closed topic for users the reopen
  # restrictions cover (TL4 users and mini-mods), instead of letting them
  # click it and hit an error. Core decides the button separately from the
  # Guardian check, via include_can_close_topic?.
  module TopicViewDetailsSerializerExtension
    def include_can_close_topic?
      topic = object.topic
      return false if topic.closed? && scope.mini_mod_reopen_restricted?(topic)
      super
    end
  end
end
