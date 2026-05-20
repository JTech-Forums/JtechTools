# frozen_string_literal: true

module DiscourseModCategories
  module GuardianExtensions
    def can_create_category?(parent = nil)
      return true if super
      mod_categories_grant?
    end

    def can_edit_category?(category)
      return true if super
      mod_categories_grant?
    end

    def can_edit_serialized_category?(category_id:, read_restricted:)
      return true if super
      mod_categories_grant?
    end

    def can_delete_category?(category)
      return true if super
      return false if !mod_categories_grant?
      category.topic_count == 0 && !category.uncategorized? && !category.has_children?
    end

    # Whether the current user may set the plugin's moderator messages
    # (per-topic footer, per-topic reply prompt). Admins always may;
    # moderators may while the plugin is enabled. Regular users never may.
    def can_manage_mod_messages?
      return true if is_admin?
      mod_categories_grant?
    end

    # A whisper post is one that carries the POST_WHISPER_TARGETS_FIELD custom
    # field — KEY PRESENCE marks it, even an empty `[]` array. It is visible
    # only to: the post author, all staff, the post's explicit targets, and
    # the topic's cumulative whisper participants. Anyone else (and anonymous
    # viewers) cannot see it.
    def can_see_post?(post)
      return super unless SiteSetting.mod_whisper_enabled
      return super unless post.is_a?(::Post)
      unless post.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
        return super
      end

      # Anonymous viewers never see whispers. Check BEFORE touching @user.id.
      return false unless authenticated?

      # Author always sees their own whisper.
      return super if post.user_id == @user.id
      # Staff (admins + moderators) see every whisper for oversight.
      return super if @user.staff?
      # Explicit user targets see it.
      return super if mod_whisper_target_ids(post).include?(@user.id)
      # Members of any explicit target group see it.
      target_group_ids = mod_whisper_target_group_ids(post)
      if target_group_ids.any? && ::GroupUser.exists?(group_id: target_group_ids, user_id: @user.id)
        return super
      end
      # Cumulative topic whisper participants see it.
      return super if mod_whisper_participant_ids(post.topic).include?(@user.id)

      false
    end

    # Whether the current user may post a whisper in the given topic. Staff
    # always may; a non-staff user may only if they are already a recorded
    # whisper participant of the topic (i.e. staff whispered to them before).
    def can_whisper_in_topic?(topic)
      return false unless SiteSetting.mod_whisper_enabled
      return false unless authenticated?
      return true if is_staff?

      mod_whisper_participant_ids(topic).include?(@user.id)
    end

    private

    def mod_whisper_target_ids(post)
      raw = post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD]
      Array(raw)
        .map { |id| id.is_a?(Numeric) || id.is_a?(String) ? id.to_i : 0 }
        .reject { |id| id <= 0 }
    end

    def mod_whisper_target_group_ids(post)
      raw = post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD]
      Array(raw)
        .map { |id| id.is_a?(Numeric) || id.is_a?(String) ? id.to_i : 0 }
        .reject { |id| id <= 0 }
    end

    def mod_whisper_participant_ids(topic)
      return [] unless topic

      raw = topic.custom_fields[DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD]
      Array(raw)
        .map { |id| id.is_a?(Numeric) || id.is_a?(String) ? id.to_i : 0 }
        .reject { |id| id <= 0 }
    end

    def mod_categories_grant?
      SiteSetting.mod_categories_enabled && is_moderator?
    end
  end
end
