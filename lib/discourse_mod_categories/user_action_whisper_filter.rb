# frozen_string_literal: true

module DiscourseModCategories
  # Filter whisper UserAction rows out of a user's public activity feed for
  # viewers who are not in the whisper audience. A whisper post is one whose
  # `posts.id` has a `mod_whisper_target_user_ids` post_custom_fields row —
  # key presence marks it, even with an empty `[]` value. The audience rules
  # mirror `GuardianExtensions#can_see_post?` and `WhisperQueryFilter`:
  #
  #   visible = post is not a whisper
  #           OR viewer is staff
  #           OR viewer is the post author
  #           OR viewer id appears in the post's explicit user targets
  #           OR viewer is a member of one of the post's target groups
  #           OR viewer holds one of the post's target badges
  #           OR viewer id appears in the topic's cumulative whisper
  #             participants list (TOPIC_WHISPER_PARTICIPANTS_FIELD)
  #
  # Anything that doesn't match is filtered. Anonymous viewers never see
  # whispers.
  #
  # `UserAction.stream` returns an Array of UserAction-like rows already
  # joined to posts/topics, so the filter runs in Ruby against the array
  # rather than reshaping the underlying SqlBuilder. This loses an exact
  # page count when a stream page contains whispers (a 30-row page becomes
  # e.g. 28 visible rows), which is acceptable — correctness of visibility
  # outranks pagination precision, and the next-page link still works
  # because the SQL window is unchanged.
  module UserActionWhisperFilter
    module_function

    # Filter `rows` (Array of UserAction-like objects, each responding to
    # `post_id` and `target_topic_id`) for `viewer` (User or nil).
    # Returns a new array containing only rows whose target_post is visible
    # to viewer per the whisper visibility rules above. Falls back to the
    # original array on any error so an upstream Discourse change can't
    # 500 the /u/{user}/activity page.
    def apply(rows, viewer)
      return rows unless SiteSetting.mod_whisper_enabled
      return rows if rows.blank?
      return rows if viewer&.staff?

      post_ids = rows.map { |r| r.respond_to?(:post_id) ? r.post_id : nil }.compact.uniq
      return rows if post_ids.empty?

      blocked_post_ids = blocked_whisper_post_ids(post_ids, viewer)
      return rows if blocked_post_ids.empty?

      rows.reject do |r|
        pid = r.respond_to?(:post_id) ? r.post_id : nil
        pid && blocked_post_ids.include?(pid)
      end
    rescue StandardError => e
      ::Rails.logger.warn(
        "[jtech-tools] UserActionWhisperFilter fell back: #{e.class}: #{e.message}",
      )
      rows
    end

    # Of `post_ids`, return the subset that are whispers NOT visible to
    # `viewer`. A single SQL round trip — joins post_custom_fields to find
    # the whisper-marked posts, then narrows with the same visibility
    # predicate WhisperQueryFilter#apply uses, inverted.
    def blocked_whisper_post_ids(post_ids, viewer)
      targets_field = DiscourseModCategories::POST_WHISPER_TARGETS_FIELD
      whisper_post_ids =
        ::PostCustomField.where(post_id: post_ids, name: targets_field).pluck(:post_id).uniq
      return [] if whisper_post_ids.empty?

      visible_ids = visible_whisper_post_ids(whisper_post_ids, viewer)
      whisper_post_ids - visible_ids
    end

    def visible_whisper_post_ids(whisper_post_ids, viewer)
      return [] if whisper_post_ids.empty?
      return [] if viewer.nil?

      scope = ::Post.where(id: whisper_post_ids)
      filtered = DiscourseModCategories::WhisperQueryFilter.apply(scope, viewer)
      filtered.pluck(:id)
    end
  end
end
