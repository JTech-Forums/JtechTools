# frozen_string_literal: true

module DiscourseMiniMod
  # Closing a topic creates the "closed this topic" small-action post after
  # the topic is already closed, so the closed-topic posting restriction
  # would block that bookkeeping post and the topic would close silently.
  # The user already passed the close permission check, so the post goes
  # through for anyone the restriction covers (TL4 users and mini-mods).
  #
  # Also refuses "open" timers from users who may not reopen the topic.
  module TopicExtension
    def add_moderator_post(user, text, opts = nil)
      opts = (opts || {}).dup

      if !opts.key?(:skip_guardian) && user.present? &&
           Guardian.new(user).mini_mod_closed_post_restricted?(self)
        opts[:skip_guardian] = true
      end

      super(user, text, opts)
    end

    # An "open" timer is a delayed reopen; users barred from reopening can't
    # schedule one (clearing an existing timer is still fine).
    def set_or_create_timer(status_type, time, by_user: nil, **opts)
      creating = time.present? || opts[:duration_minutes].present?
      if creating && status_type == TopicTimer.types[:open] && by_user &&
           Guardian.new(by_user).mini_mod_reopen_restricted?(self)
        raise Discourse::InvalidAccess
      end
      super
    end
  end
end
