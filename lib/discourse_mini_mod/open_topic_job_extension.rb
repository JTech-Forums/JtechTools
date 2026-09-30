# frozen_string_literal: true

module DiscourseMiniMod
  # An "open" timer left by a user who may no longer reopen the topic (the
  # restriction was switched on after it was set) is dropped quietly, the
  # way core drops a timer whose owner lost the right to set it.
  module OpenTopicJobExtension
    def execute_timer_action(topic_timer, topic)
      user = topic_timer.user
      if user && topic.closed? && Guardian.new(user).mini_mod_reopen_restricted?(topic)
        topic_timer.destroy!
        return
      end
      super
    end
  end
end
