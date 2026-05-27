# frozen_string_literal: true

module ::DiscourseModCategories
  # Persistence endpoint for the moderator-set messages. Every action is
  # Guardian-gated so only moderators and admins can write; regular users
  # get a 403.
  class MessagesController < ::ApplicationController
    requires_plugin "jtech-tools"
    requires_login

    TOPIC_FOOTER_FIELD = DiscourseModCategories::TOPIC_FOOTER_FIELD
    TOPIC_REPLY_PROMPT_FIELD = DiscourseModCategories::TOPIC_REPLY_PROMPT_FIELD
    TOPIC_PINNED_POST_FIELD = DiscourseModCategories::TOPIC_PINNED_POST_FIELD
    TOPIC_REQUIRE_REPLY_APPROVAL_FIELD = DiscourseModCategories::TOPIC_REQUIRE_REPLY_APPROVAL_FIELD
    TOPIC_PRIVATE_NOTE_FIELD = DiscourseModCategories::TOPIC_PRIVATE_NOTE_FIELD
    TOPIC_PRIVATE_NOTE_POSITION_FIELD = DiscourseModCategories::TOPIC_PRIVATE_NOTE_POSITION_FIELD
    TOPIC_PRIVATE_NOTE_USER_FIELD = DiscourseModCategories::TOPIC_PRIVATE_NOTE_USER_FIELD
    TOPIC_PRIVATE_NOTE_CREATED_AT_FIELD =
      DiscourseModCategories::TOPIC_PRIVATE_NOTE_CREATED_AT_FIELD
    TOPIC_PRIVATE_NOTE_REPLIES_FIELD = DiscourseModCategories::TOPIC_PRIVATE_NOTE_REPLIES_FIELD
    TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD = DiscourseModCategories::TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD
    USER_NOTES_SEEN_FIELD = DiscourseModCategories::USER_NOTES_SEEN_FIELD
    CATEGORY_NEW_TOPIC_PROMPT_FIELD = DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_FIELD
    TOPIC_REPLY_PROMPT_TL_FIELD = DiscourseModCategories::TOPIC_REPLY_PROMPT_TL_FIELD
    CATEGORY_NEW_TOPIC_PROMPT_TL_FIELD = DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_TL_FIELD
    TOPIC_WHISPER_PARTICIPANTS_FIELD = DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD

    def update_topic
      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic

      guardian.ensure_can_manage_mod_messages!

      if params.key?(:footer_message)
        topic.custom_fields[TOPIC_FOOTER_FIELD] = params[:footer_message].to_s
      end

      if params.key?(:reply_prompt)
        topic.custom_fields[TOPIC_REPLY_PROMPT_FIELD] = params[:reply_prompt].to_s
      end

      if params.key?(:reply_prompt_max_tl)
        topic.custom_fields[TOPIC_REPLY_PROMPT_TL_FIELD] = normalize_max_tl(
          params[:reply_prompt_max_tl],
        )
      end

      if params.key?(:pinned_post_id)
        raw = params[:pinned_post_id].to_s.strip
        if raw.empty? || raw == "0"
          topic.custom_fields[TOPIC_PINNED_POST_FIELD] = nil
        else
          post = topic.posts.find_by(id: raw.to_i)
          raise Discourse::InvalidParameters.new(:pinned_post_id) unless post
          topic.custom_fields[TOPIC_PINNED_POST_FIELD] = post.id
        end
      end

      if params.key?(:require_reply_approval)
        topic.custom_fields[
          TOPIC_REQUIRE_REPLY_APPROVAL_FIELD
        ] = ActiveModel::Type::Boolean.new.cast(params[:require_reply_approval]) || false
      end

      if params.key?(:private_note)
        topic.custom_fields[TOPIC_PRIVATE_NOTE_FIELD] = params[:private_note].to_s
        # Record who set the note, and when, so it can be shown like a post.
        topic.custom_fields[TOPIC_PRIVATE_NOTE_USER_FIELD] = current_user.id
        topic.custom_fields[TOPIC_PRIVATE_NOTE_CREATED_AT_FIELD] = Time.zone.now.iso8601
        topic.custom_fields[TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD] = Time.zone.now.iso8601
      end

      if params.key?(:private_note_position)
        position = params[:private_note_position].to_s
        position = "bottom" if %w[top bottom].exclude?(position)
        topic.custom_fields[TOPIC_PRIVATE_NOTE_POSITION_FIELD] = position
      end

      topic.save_custom_fields(true)

      if params.key?(:private_note) && topic.custom_fields[TOPIC_PRIVATE_NOTE_FIELD].present?
        notify_staff_of_note(topic)
      end

      render json: {
               footer_message: topic.custom_fields[TOPIC_FOOTER_FIELD].to_s,
               reply_prompt: topic.custom_fields[TOPIC_REPLY_PROMPT_FIELD].to_s,
               reply_prompt_max_tl: topic.custom_fields[TOPIC_REPLY_PROMPT_TL_FIELD],
               pinned_post_id: topic.custom_fields[TOPIC_PINNED_POST_FIELD],
               require_reply_approval: !!topic.custom_fields[TOPIC_REQUIRE_REPLY_APPROVAL_FIELD],
               private_note: topic.custom_fields[TOPIC_PRIVATE_NOTE_FIELD].to_s,
               private_note_position:
                 topic.custom_fields[TOPIC_PRIVATE_NOTE_POSITION_FIELD].presence || "bottom",
               private_note_author: private_note_author(topic),
             }
    end

    def update_category
      category = Category.find_by(id: params[:category_id])
      raise Discourse::NotFound unless category

      # Editing a category is already a moderator-granted ability in this
      # plugin; reuse that gate for the per-category prompt.
      guardian.ensure_can_edit_category!(category)

      category.custom_fields[CATEGORY_NEW_TOPIC_PROMPT_FIELD] = params[:new_topic_prompt].to_s

      if params.key?(:new_topic_prompt_max_tl)
        category.custom_fields[CATEGORY_NEW_TOPIC_PROMPT_TL_FIELD] = normalize_max_tl(
          params[:new_topic_prompt_max_tl],
        )
      end

      category.save_custom_fields(true)

      render json: {
               new_topic_prompt: category.custom_fields[CATEGORY_NEW_TOPIC_PROMPT_FIELD].to_s,
               new_topic_prompt_max_tl: category.custom_fields[CATEGORY_NEW_TOPIC_PROMPT_TL_FIELD],
             }
    end

    # Appends a staff reply to the topic's private moderator note thread.
    def add_note_reply
      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic

      guardian.ensure_can_manage_mod_messages!

      raw = params[:raw].to_s.strip
      raise Discourse::InvalidParameters.new(:raw) if raw.empty?

      replies = note_replies(topic)
      reply = {
        "id" => SecureRandom.hex(8),
        "user_id" => current_user.id,
        "raw" => raw,
        "created_at" => Time.zone.now.iso8601,
      }
      replies << reply
      topic.custom_fields[TOPIC_PRIVATE_NOTE_REPLIES_FIELD] = replies
      topic.custom_fields[TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD] = Time.zone.now.iso8601
      topic.save_custom_fields(true)
      notify_staff_of_reply(topic, reply)

      render json: { replies: serialized_note_replies(topic) }
    end

    # Edits the `raw` body of a single reply in the note thread.
    def update_note_reply
      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic

      guardian.ensure_can_manage_mod_messages!

      raw = params[:raw].to_s.strip
      raise Discourse::InvalidParameters.new(:raw) if raw.empty?

      reply_id = params[:reply_id].to_s
      replies = note_replies(topic)
      reply = replies.find { |r| r["id"] == reply_id }
      raise Discourse::InvalidParameters.new(:reply_id) unless reply

      reply["raw"] = raw
      topic.custom_fields[TOPIC_PRIVATE_NOTE_REPLIES_FIELD] = replies
      topic.custom_fields[TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD] = Time.zone.now.iso8601
      topic.save_custom_fields(true)

      render json: note_thread_json(topic)
    end

    # Removes a single reply from the note thread.
    def delete_note_reply
      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic

      guardian.ensure_can_manage_mod_messages!

      reply_id = params[:reply_id].to_s
      replies = note_replies(topic)
      unless replies.any? { |r| r["id"] == reply_id }
        raise Discourse::InvalidParameters.new(:reply_id)
      end

      replies.reject! { |r| r["id"] == reply_id }
      topic.custom_fields[TOPIC_PRIVATE_NOTE_REPLIES_FIELD] = replies
      topic.custom_fields[TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD] = Time.zone.now.iso8601
      topic.save_custom_fields(true)

      render json: note_thread_json(topic)
    end

    # Clears the note body, its author/created-at, and its whole reply thread.
    def delete_note
      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic

      guardian.ensure_can_manage_mod_messages!

      topic.custom_fields[TOPIC_PRIVATE_NOTE_FIELD] = ""
      topic.custom_fields[TOPIC_PRIVATE_NOTE_USER_FIELD] = nil
      topic.custom_fields[TOPIC_PRIVATE_NOTE_CREATED_AT_FIELD] = nil
      topic.custom_fields[TOPIC_PRIVATE_NOTE_REPLIES_FIELD] = []
      topic.custom_fields[TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD] = Time.zone.now.iso8601
      topic.save_custom_fields(true)

      render json: note_thread_json(topic)
    end

    # Lists recent moderator notes across topics, for the staff user-menu
    # tab, newest first.
    def notes_feed
      guardian.ensure_can_manage_mod_messages!

      topic_ids =
        TopicCustomField
          .where(name: TOPIC_PRIVATE_NOTE_FIELD)
          .where.not(value: [nil, ""])
          .order(updated_at: :desc)
          .limit(50)
          .pluck(:topic_id)

      seen_at = current_user.custom_fields[USER_NOTES_SEEN_FIELD].presence || "1970-01-01T00:00:00Z"

      notes =
        Topic
          .where(id: topic_ids)
          .map do |topic|
            note = topic.custom_fields[TOPIC_PRIVATE_NOTE_FIELD].to_s
            next if note.blank?
            replies = topic.custom_fields[TOPIC_PRIVATE_NOTE_REPLIES_FIELD]
            activity_at = topic.custom_fields[TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD].to_s
            {
              topic_id: topic.id,
              topic_title: topic.title,
              url: "#{topic.relative_url}/#{topic.highest_post_number}#mod-private-note",
              note: note,
              reply_count: replies.is_a?(Array) ? replies.size : 0,
              activity_at: activity_at,
              unread: activity_at > seen_at,
            }
          end
          .compact
          .sort_by { |n| n[:activity_at] }
          .reverse

      render json: { notes: notes }
    end

    # Marks the staff user's moderator-note feed as read.
    def notes_feed_seen
      guardian.ensure_can_manage_mod_messages!

      current_user.with_lock do
        current_user.custom_fields[USER_NOTES_SEEN_FIELD] = Time.zone.now.iso8601
        current_user.save_custom_fields(true)
      end

      # Also flip the underlying Notification rows to read. Otherwise the
      # bell counter keeps reflecting the prior mod-note bumps after the
      # shield tab has cleared them — Discourse counts unread Notifications,
      # not our custom seen_at timestamp. The `mod_note` marker in the JSON
      # `data` column distinguishes our notifications from other custom
      # ones so we only touch our own rows.
      marked =
        Notification
          .where(
            user_id: current_user.id,
            notification_type: Notification.types[:custom],
            read: false,
          )
          .where("data LIKE ?", "%\"mod_note\":true%")
          .update_all(read: true)

      # Push the recalculated bell counts to every open tab so they refresh
      # in lockstep with the shield tab being opened. This also drops the
      # in-dropdown shield-tab pip, which now derives from unread Notification
      # rows (the same source the bell uses), so it stays in lockstep with
      # the bell badge without a dedicated MessageBus channel.
      current_user.publish_notifications_state if marked > 0

      render json: success_json
    end

    # Resolves a badge id to the current set of usernames who hold it.
    # Used by the PM composer "Add badge group" button to splice badge
    # holders into the standard `target_recipients` field — the PM is then
    # sent through the normal PostCreator path with no further plugin code.
    # Self is excluded (no point messaging yourself); the list is deduped.
    def badge_members
      guardian.ensure_can_send_private_messages!
      badge = Badge.find_by(id: params[:badge_id])
      raise Discourse::NotFound unless badge

      usernames =
        User
          .joins(:user_badges)
          .where(user_badges: { badge_id: badge.id })
          .where(active: true)
          .where.not(id: current_user.id)
          .distinct
          .pluck(:username)

      render json: { usernames: usernames, badge: { id: badge.id, name: badge.display_name } }
    end

    # Adds a user to a topic's cumulative whisper conversation. From then on
    # that user sees every whisper in the topic (both Guardian#can_see_post?
    # and the topic-stream SQL filter grant visibility to participants).
    def add_whisper_participant
      raise Discourse::NotFound unless SiteSetting.mod_whisper_enabled

      topic = Topic.find_by(id: params[:topic_id])
      raise Discourse::NotFound unless topic

      guardian.ensure_can_manage_mod_messages!

      user =
        if params[:user_id].present?
          User.find_by(id: params[:user_id])
        elsif params[:username].present?
          User.find_by_username(params[:username])
        end
      raise Discourse::InvalidParameters.new(:username) unless user

      existing = Array(topic.custom_fields[TOPIC_WHISPER_PARTICIPANTS_FIELD]).map(&:to_i)
      merged = (existing + [user.id]).reject { |i| i <= 0 }.uniq

      if merged.sort != existing.sort
        topic.custom_fields[TOPIC_WHISPER_PARTICIPANTS_FIELD] = merged
        topic.save_custom_fields(true)
        notify_whisper_participant(topic, user)
      end

      render json: { participant_ids: merged }
    end

    private

    # Notifies a newly added user that they were added to the topic's whisper
    # conversation, mirroring the whisper `post_created` notification pattern.
    def notify_whisper_participant(topic, user)
      return if user.id == current_user.id

      Notification.create!(
        notification_type: Notification.types[:custom],
        user_id: user.id,
        topic_id: topic.id,
        post_number: topic.highest_post_number,
        data: {
          topic_title: topic.title,
          display_username: current_user.username,
          message: "discourse_mod_categories.whisper.whisper_notification",
        }.to_json,
      )
    end

    # Clamps a submitted trust-level cap to 0-4. 4 (the default) means the
    # prompt is shown to everyone; 0-3 limits it to that trust level and
    # below.
    def normalize_max_tl(value)
      [[value.to_i, 0].max, 4].min
    end

    # Sends a real Discourse notification (bell + live pop-up) to every
    # other staff member when a moderator note or reply is added.
    #
    # The notification carries `high_priority: true` so it sorts and badges
    # like a flag/review notification, and a `mod_note` marker in `data` so
    # the frontend notification-type renderer can render it with the shield
    # icon, accurate text, and a link straight to the moderator note. The
    # note lives on the topic, so the link resolves to the topic at its
    # highest post number with a `#mod-private-note` anchor so the browser
    # (and the component's own scroll-into-view) lands on the note section
    # instead of the topic's first post when the topic is short.
    #
    # The live pop-up alert is published on the same `/notification-alert/`
    # MessageBus channel core uses for flags/replies. Creating a
    # `Notification` row alone only fills the bell list — it never pops up.
    def notify_staff_of_note(topic)
      note = topic.custom_fields[TOPIC_PRIVATE_NOTE_FIELD].to_s
      note_url = "#{topic.relative_url}/#{topic.highest_post_number}#mod-private-note"

      User
        .where(admin: true)
        .or(User.where(moderator: true))
        .where.not(id: current_user.id)
        .find_each do |staff_user|
          data = {
            topic_title: topic.title,
            display_username: current_user.username,
            # Stable marker the frontend renderer keys off to recognize THIS
            # custom notification as a moderator note.
            mod_note: true,
            mod_note_kind: "note",
            excerpt: note.truncate(300),
            url: note_url,
            message: "discourse_mod_categories.note_notification",
            title: "discourse_mod_categories.note_notification_title",
          }

          Notification.create!(
            notification_type: Notification.types[:custom],
            user_id: staff_user.id,
            topic_id: topic.id,
            post_number: topic.highest_post_number,
            high_priority: true,
            data: data.to_json,
          )

          publish_note_alert(staff_user, topic, note, note_url)
          # The standard /notifications poll picks up the new unread row so
          # both the bell dot and the in-dropdown shield-tab pip refresh
          # together. No separate /mod-note-unread-count channel is needed.
          staff_user.publish_notifications_state
        end
    end

    # Sends a notification for a single reply in the moderator-note thread.
    # Each reply gets its own bell row and live pop-up — carrying the reply
    # author, the reply excerpt, and a URL anchored at the specific reply —
    # so multiple replies in the same topic stack as distinct entries instead
    # of looking like duplicate "note added" rows.
    def notify_staff_of_reply(topic, reply)
      reply_id = reply["id"].to_s
      reply_raw = reply["raw"].to_s
      reply_url = "#{topic.relative_url}/#{topic.highest_post_number}#mod-private-note-reply-#{reply_id}"

      User
        .where(admin: true)
        .or(User.where(moderator: true))
        .where.not(id: current_user.id)
        .find_each do |staff_user|
          data = {
            topic_title: topic.title,
            display_username: current_user.username,
            mod_note: true,
            mod_note_kind: "reply",
            reply_id: reply_id,
            excerpt: reply_raw.truncate(300),
            url: reply_url,
            message: "discourse_mod_categories.note_reply_notification",
            title: "discourse_mod_categories.note_reply_notification_title",
          }

          Notification.create!(
            notification_type: Notification.types[:custom],
            user_id: staff_user.id,
            topic_id: topic.id,
            post_number: topic.highest_post_number,
            high_priority: true,
            data: data.to_json,
          )

          publish_reply_alert(staff_user, topic, reply_raw, reply_url)
          staff_user.publish_notifications_state
        end
    end

    # Fires the small live notification pop-up for one staff member. The
    # payload mirrors `PostAlerter.create_notification_alert`, but carries an
    # explicit `translated_title` so the pop-up text clearly names a
    # moderator note, and a `post_url` pointing straight at the note.
    def publish_note_alert(staff_user, topic, note, note_url)
      return if staff_user.suspended?
      return unless staff_user.allow_live_notifications?

      payload = {
        notification_type: Notification.types[:custom],
        topic_title: topic.title,
        topic_id: topic.id,
        post_number: topic.highest_post_number,
        excerpt: note.truncate(300),
        username: current_user.username,
        post_url: note_url,
        translated_title:
          I18n.t(
            "discourse_mod_categories.note_notification_alert",
            username: current_user.username,
            topic: topic.title,
          ),
      }

      MessageBus.publish("/notification-alert/#{staff_user.id}", payload, user_ids: [staff_user.id])
    end

    # Per-reply variant of publish_note_alert — the excerpt is the reply body
    # so a stack of replies pops up as distinct toasts, and the title says
    # "replied to" so the recipient can tell a reply from the original note.
    def publish_reply_alert(staff_user, topic, reply_raw, reply_url)
      return if staff_user.suspended?
      return unless staff_user.allow_live_notifications?

      payload = {
        notification_type: Notification.types[:custom],
        topic_title: topic.title,
        topic_id: topic.id,
        post_number: topic.highest_post_number,
        excerpt: reply_raw.truncate(300),
        username: current_user.username,
        post_url: reply_url,
        translated_title:
          I18n.t(
            "discourse_mod_categories.note_reply_notification_alert",
            username: current_user.username,
            topic: topic.title,
          ),
      }

      MessageBus.publish("/notification-alert/#{staff_user.id}", payload, user_ids: [staff_user.id])
    end

    def private_note_author(topic)
      user_id = topic.custom_fields[TOPIC_PRIVATE_NOTE_USER_FIELD]
      user = user_id && User.find_by(id: user_id)
      return nil unless user

      { username: user.username, name: user.name, avatar_template: user.avatar_template }
    end

    # Reads the topic's reply thread, backfilling a stable `id` onto any
    # legacy reply that predates ids so edit/delete can target it.
    def note_replies(topic)
      replies = topic.custom_fields[TOPIC_PRIVATE_NOTE_REPLIES_FIELD]
      replies = [] unless replies.is_a?(Array)
      replies.each { |entry| entry["id"] = SecureRandom.hex(8) if entry["id"].blank? }
      replies
    end

    # The updated note + replies JSON returned by every note-thread action so
    # the frontend can refresh without an extra request.
    def note_thread_json(topic)
      {
        private_note: topic.custom_fields[TOPIC_PRIVATE_NOTE_FIELD].to_s,
        private_note_author: private_note_author(topic),
        private_note_created_at: topic.custom_fields[TOPIC_PRIVATE_NOTE_CREATED_AT_FIELD],
        replies: serialized_note_replies(topic),
      }
    end

    def serialized_note_replies(topic)
      note_replies(topic).map do |entry|
        author = entry["user_id"] && User.find_by(id: entry["user_id"])
        {
          id: entry["id"],
          raw: entry["raw"].to_s,
          created_at: entry["created_at"],
          author:
            author &&
              {
                username: author.username,
                name: author.name,
                avatar_template: author.avatar_template,
              },
        }
      end
    end
  end
end
