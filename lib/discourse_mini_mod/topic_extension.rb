# frozen_string_literal: true

module DiscourseMiniMod
  # When a mini-mod closes a topic, TopicStatusUpdater synchronously creates a
  # "@user closed this topic" small action post via Topic#add_moderator_post.
  # By the time PostCreator runs its Guardian check, the topic has already been
  # marked closed, so our can_create_post_on_topic? override blocks the small
  # action post creation and the topic ends up closed but missing its
  # announcement line.
  #
  # The user already passed the operational permission check
  # (ensure_can_close_topic! -> can_close_topic?) before reaching this method,
  # so the Guardian check on the bookkeeping post is redundant. We pass
  # skip_guardian: true on add_moderator_post for non-staff mini-mods so the
  # small action post always lands.
  module TopicExtension
    def add_moderator_post(user, text, opts = nil)
      opts = (opts || {}).dup

      if !opts.key?(:skip_guardian) && SiteSetting.mini_mod_enabled &&
           !SiteSetting.mini_mod_can_post_in_closed_topics && user.present? && !user.staff? &&
           category.present? && Guardian.new(user).is_category_group_moderator?(category)
        opts[:skip_guardian] = true
      end

      super(user, text, opts)
    end
  end
end
