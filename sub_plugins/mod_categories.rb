# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `discourse-mod/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.

require_relative "../lib/discourse_mod_categories/guardian_extensions"
require_relative "../lib/discourse_mod_categories/whisper_query_filter"

register_asset "stylesheets/topic-footer-message.scss"
register_asset "stylesheets/whisper.scss"
register_svg_icon "list-check"
register_svg_icon "shield-halved"
register_svg_icon "user-plus"
register_svg_icon "pencil"
register_svg_icon "trash-can"
register_svg_icon "certificate"
register_svg_icon "eye"

module ::DiscourseModCategories
  # Custom-field keys for the moderator-set messages.
  TOPIC_FOOTER_FIELD = "mod_topic_footer_message"
  TOPIC_REPLY_PROMPT_FIELD = "mod_topic_reply_prompt"
  TOPIC_PINNED_POST_FIELD = "mod_topic_pinned_post_id"
  TOPIC_REQUIRE_REPLY_APPROVAL_FIELD = "mod_topic_require_reply_approval"
  TOPIC_PRIVATE_NOTE_FIELD = "mod_topic_private_note"
  TOPIC_PRIVATE_NOTE_POSITION_FIELD = "mod_topic_private_note_position"
  TOPIC_PRIVATE_NOTE_USER_FIELD = "mod_topic_private_note_user_id"
  TOPIC_PRIVATE_NOTE_CREATED_AT_FIELD = "mod_topic_private_note_created_at"
  TOPIC_PRIVATE_NOTE_REPLIES_FIELD = "mod_topic_private_note_replies"
  TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD = "mod_topic_private_note_activity_at"
  USER_NOTES_SEEN_FIELD = "mod_notes_seen_at"
  CATEGORY_NEW_TOPIC_PROMPT_FIELD = "mod_category_new_topic_prompt"
  # Highest trust level still shown a prompt (0-3); 4/blank means everyone.
  TOPIC_REPLY_PROMPT_TL_FIELD = "mod_topic_reply_prompt_max_tl"
  CATEGORY_NEW_TOPIC_PROMPT_TL_FIELD = "mod_category_new_topic_prompt_max_tl"
  # Forum-wide first-post checklist: the config lives in the plugin store,
  # and each user records the highest checklist version they have accepted.
  USER_CHECKLIST_VERSION_FIELD = "mod_checklist_accepted_version"
  CHECKLIST_STORE_NAMESPACE = "discourse_mod_categories"
  CHECKLIST_STORE_KEY = "first_post_checklist"
  # Append-only audit log of checklist acceptances.
  CHECKLIST_LOG_KEY = "first_post_checklist_log"
  # Targeted checklists: separate checklists aimed at specific users,
  # stored as a JSON array under this key. A per-user json map records the
  # version each targeted checklist was last accepted at.
  TARGETED_CHECKLISTS_KEY = "targeted_checklists"
  USER_TARGETED_CHECKLIST_FIELD = "mod_checklist_targeted_accepted"
  # Per-topic prompt checklist: an opt-in checklist attached to a single
  # topic. The checklist itself lives on the topic custom field; each user
  # records which version (per topic id) they have accepted in their own
  # json map custom field.
  TOPIC_PROMPT_CHECKLIST_FIELD = "mod_topic_prompt_checklist"
  USER_TOPIC_CHECKLIST_FIELD = "mod_topic_checklist_accepted"

  # The current checklist config, or nil when none is set. Shape:
  #   { "version" => Integer, "items" => [{ "label" =>, "url" => }],
  #     "updated_at" => ISO8601 String }
  def self.checklist_config
    PluginStore.get(CHECKLIST_STORE_NAMESPACE, CHECKLIST_STORE_KEY)
  end

  # The single checklist the given user most needs to accept before they
  # can post, or nil so the caller can skip the modal. This is the SINGLE
  # source of truth shared by the `mod_first_post_checklist` serializer and
  # the `/checklist/owed` endpoint, so the two can never diverge.
  #
  # Priority: targeted > per-topic > global. A targeted checklist applies
  # regardless of trust level or staff status. A per-topic checklist, when
  # `topic_id` is supplied, applies to every user (including staff) who
  # has not yet accepted the current version for that topic. Failing both,
  # the forum-wide checklist applies under the usual rules (non-staff,
  # trust-level cap). A user owing several is shown the highest-priority one.
  def self.owed_checklist_for(user, topic_id: nil)
    return nil unless user
    return nil unless SiteSetting.mod_categories_enabled

    # --- Targeted checklists (override trust level and staff status) ---
    targeted_accepted = user.custom_fields[USER_TARGETED_CHECKLIST_FIELD]
    targeted_accepted = {} unless targeted_accepted.is_a?(Hash)

    owed_targeted =
      targeted_checklists.find do |checklist|
        items = checklist["items"]
        next false unless items.is_a?(Array) && items.any?
        next false if Array(checklist["user_ids"]).map(&:to_i).exclude?(user.id)
        checklist["version"].to_i > targeted_accepted[checklist["id"]].to_i
      end

    if owed_targeted
      return(
        {
          kind: "targeted",
          id: owed_targeted["id"],
          version: owed_targeted["version"].to_i,
          items: owed_targeted["items"],
          button_label: owed_targeted["button_label"].to_s,
          updated_at: owed_targeted["updated_at"],
        }
      )
    end

    # --- Per-topic checklist (applies to everyone, including staff) ---
    # Mode is "checklist" (the default historical shape) or "statement"
    # (a single message + accept button). Frequency is "once" (default,
    # per-user-version-tracked) or "every_reply" (always prompt). A
    # max_tl cap filters higher-trust non-staff users out. Targeted
    # checklists already short-circuited above so they always show.
    if topic_id.present?
      topic_checklist = topic_prompt_checklist(topic_id)
      if topic_checklist
        mode = topic_checklist["mode"].to_s
        mode = "checklist" if %w[statement checklist].exclude?(mode)
        frequency = topic_checklist["frequency"].to_s
        frequency = "once" if %w[once every_reply].exclude?(frequency)

        max_tl =
          if topic_checklist.key?("max_tl")
            topic_checklist["max_tl"].to_i
          else
            4
          end

        # Trust-level cap (non-staff only); 4 = everyone.
        below_cap = !user.staff? && user.trust_level > max_tl

        unless below_cap
          version = topic_checklist["version"].to_i
          accepted_version = 0
          if frequency == "once"
            accepted_map = user.custom_fields[USER_TOPIC_CHECKLIST_FIELD]
            accepted_map =
              begin
                JSON.parse(accepted_map)
              rescue StandardError
                {}
              end if accepted_map.is_a?(String)
            accepted_map = {} unless accepted_map.is_a?(Hash)
            accepted_version = accepted_map[topic_id.to_s].to_i
          end

          if frequency == "every_reply" || version > accepted_version
            return(
              {
                kind: "topic",
                id: topic_id.to_i,
                version: version,
                mode: mode,
                statement: topic_checklist["statement"].to_s,
                items: topic_checklist["items"],
                frequency: frequency,
                max_tl: max_tl,
                button_label: topic_checklist["button_label"].to_s,
                updated_at: topic_checklist["updated_at"],
              }
            )
          end
        end
      end
    end

    # --- Forum-wide checklist (staff excluded, trust-level cap) ---
    return nil if user.staff?

    config = checklist_config
    return nil unless config

    items = config["items"]
    return nil unless items.is_a?(Array) && items.any?

    # Highest trust level still required to accept (default TL2).
    max_tl = config.key?("max_tl") ? config["max_tl"].to_i : 2
    return nil if user.trust_level > max_tl

    version = config["version"].to_i
    accepted = user.custom_fields[USER_CHECKLIST_VERSION_FIELD].to_i
    return nil if accepted >= version

    {
      kind: "global",
      version: version,
      items: items,
      button_label: config["button_label"].to_s,
      updated_at: config["updated_at"],
    }
  end

  # The per-topic prompt checklist hash for a given topic, or nil. Returns
  # the parsed json structure when the config is active (checklist mode
  # with at least one item, or statement mode with a non-blank statement),
  # else nil to mean "inactive". The custom field stores json, so the
  # value may already be a hash; older saves may have stored a string, so
  # coerce that case too.
  def self.topic_prompt_checklist(topic_id)
    return nil if topic_id.blank?
    topic = Topic.find_by(id: topic_id)
    return nil unless topic

    raw = topic.custom_fields[TOPIC_PROMPT_CHECKLIST_FIELD]
    raw =
      begin
        JSON.parse(raw)
      rescue StandardError
        nil
      end if raw.is_a?(String)
    return nil unless raw.is_a?(Hash)

    mode = raw["mode"].to_s
    mode = "checklist" if %w[statement checklist].exclude?(mode)

    if mode == "statement"
      return nil if raw["statement"].to_s.strip.empty?
    else
      items = raw["items"]
      return nil unless items.is_a?(Array) && items.any?
    end

    raw
  end

  # The list of targeted checklists, an array of
  #   { "id", "name", "user_ids" => [Integer], "items" => [{ "label", "url" }],
  #     "version" => Integer, "button_label" }
  def self.targeted_checklists
    raw = PluginStore.get(CHECKLIST_STORE_NAMESPACE, TARGETED_CHECKLISTS_KEY)
    raw.is_a?(Array) ? raw : []
  end

  # Moderator whisper: a per-post custom field holding the chosen target user
  # ids (json int array). KEY PRESENCE marks the post as a whisper — even an
  # empty `[]` array (a staff-only whisper-back). The per-topic field holds
  # the cumulative set of non-staff users ever whispered to in the topic.
  POST_WHISPER_TARGETS_FIELD = "mod_whisper_target_user_ids"
  # A whisper may also target whole groups; this per-post field holds the
  # chosen group ids (json int array). A member of ANY target group can see
  # the whisper. User targets and group targets are independent — a whisper
  # may carry either, both, or neither (an all-empty staff whisper).
  POST_WHISPER_TARGET_GROUPS_FIELD = "mod_whisper_target_group_ids"
  # A whisper may target the holders of one or more badges; this per-post
  # field holds the chosen badge ids (json int array). Membership is
  # evaluated lazily at query time, so a user who later earns the badge
  # gains visibility and a user who loses it loses visibility — same shape
  # as group targets.
  POST_WHISPER_TARGET_BADGES_FIELD = "mod_whisper_target_badge_ids"
  TOPIC_WHISPER_PARTICIPANTS_FIELD = "mod_whisper_participant_ids"
  # ISO8601 timestamp of the latest NON-whisper post in the topic. Written
  # alongside the highest_post_number rollback so the topic-list query
  # modifier can sort non-audience users by this value instead of the live
  # Topic#bumped_at, while audience members keep the actual bump time.
  TOPIC_NON_WHISPER_BUMPED_AT_FIELD = "mod_non_whisper_bumped_at"
  # JSON array of `{user_id, username, name, avatar_template, viewed_at}`
  # entries — staff who have rendered the mod-note panel on the topic.
  # Used by the "👁 Viewed by N" pill at the bottom of the panel. Re-view
  # updates the entry's `viewed_at` in place (one row per user).
  TOPIC_NOTE_VIEWERS_FIELD = "mod_topic_note_viewers"
  MAX_WHISPER_TARGETS = 10
  # Explicit boolean armed flag sent by the composer. A boolean survives
  # form-encoding even when the target id array is empty, so it — not the
  # target count — is the single source of truth for "this post is a whisper".
  POST_WHISPER_ARMED_PARAM = "mod_whisper"

  # Highest post_number in the topic that the given user can actually see —
  # i.e. excluding whispers whose audience does not include them. Used as the
  # per-user serialized `highest_post_number` so the topic-list unread badge
  # is audience-aware: non-audience viewers see no badge bump from whispers,
  # while audience members (staff, explicit user/group targets, topic whisper
  # participants) see the whisper post count toward unread.
  def self.whisper_audience_max_post_number(topic, user)
    return nil unless topic
    scope = ::Post.where(topic_id: topic.id, deleted_at: nil)
    scope = WhisperQueryFilter.apply(scope, user)
    scope.maximum(:post_number)
  end

  class Engine < ::Rails::Engine
    engine_name "discourse_mod_categories"
    isolate_namespace DiscourseModCategories
  end
end

after_initialize do
  reloadable_patch { ::Guardian.prepend(DiscourseModCategories::GuardianExtensions) }

  # Keep the shield-tab pip in sync when a mod-note notification is marked
  # read from the standard bell dropdown. The reverse direction (opening the
  # shield tab → marking the bell rows read) is already wired in
  # MessagesController#notes_feed_seen via publish_notifications_state. This
  # hook gives a single-row bell mark-read the same effect: republishing the
  # bell count tells the user-state poll that the unread total dropped, and
  # the next /session/current.json (or current-user serializer refresh) picks
  # up the recomputed mod_note_unread_count.
  reloadable_patch do
    ::Notification.after_update_commit do
      next unless saved_change_to_read?
      next unless read
      next unless notification_type == ::Notification.types[:custom]
      next if data.to_s.exclude?('"mod_note":true')
      user = ::User.find_by(id: user_id)
      user&.publish_notifications_state
    end
  end

  # Per-topic and per-category storage for the moderator-set messages.
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_FOOTER_FIELD, :string)
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_REPLY_PROMPT_FIELD, :string)
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_PINNED_POST_FIELD, :integer)
  register_topic_custom_field_type(
    DiscourseModCategories::TOPIC_REQUIRE_REPLY_APPROVAL_FIELD,
    :boolean,
  )
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_PRIVATE_NOTE_FIELD, :string)
  register_topic_custom_field_type(
    DiscourseModCategories::TOPIC_PRIVATE_NOTE_POSITION_FIELD,
    :string,
  )
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_PRIVATE_NOTE_USER_FIELD, :integer)
  register_topic_custom_field_type(
    DiscourseModCategories::TOPIC_PRIVATE_NOTE_CREATED_AT_FIELD,
    :string,
  )
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_PRIVATE_NOTE_REPLIES_FIELD, :json)
  register_topic_custom_field_type(
    DiscourseModCategories::TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD,
    :string,
  )
  register_topic_custom_field_type(
    DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD,
    :string,
  )
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_NOTE_VIEWERS_FIELD, :json)

  # Preload the two custom fields the audience-aware bumped_at serializer
  # below reads. Without these, Discourse's HasCustomFields::PreloadedProxy
  # raises NotPreloadedError when the serializer touches the fields on a
  # topic-list row (the guard exists to prevent N+1 queries — preloading
  # is the documented way to declare you intend to use the field for
  # every topic on the list).
  add_preloaded_topic_list_custom_field(DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD)
  add_preloaded_topic_list_custom_field(DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD)
  register_user_custom_field_type(DiscourseModCategories::USER_NOTES_SEEN_FIELD, :string)
  register_user_custom_field_type(DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD, :integer)
  register_user_custom_field_type(DiscourseModCategories::USER_TARGETED_CHECKLIST_FIELD, :json)
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_PROMPT_CHECKLIST_FIELD, :json)
  register_user_custom_field_type(DiscourseModCategories::USER_TOPIC_CHECKLIST_FIELD, :json)
  register_category_custom_field_type(
    DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_FIELD,
    :string,
  )
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_REPLY_PROMPT_TL_FIELD, :integer)
  register_category_custom_field_type(
    DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_TL_FIELD,
    :integer,
  )

  # Expose the per-topic messages to the topic view so the frontend can
  # read them without an extra request.
  add_to_serializer(:topic_view, :mod_topic_footer_message) do
    object.topic.custom_fields[DiscourseModCategories::TOPIC_FOOTER_FIELD]
  end
  add_to_serializer(:topic_view, :mod_topic_reply_prompt) do
    object.topic.custom_fields[DiscourseModCategories::TOPIC_REPLY_PROMPT_FIELD]
  end
  add_to_serializer(:topic_view, :mod_topic_reply_prompt_max_tl) do
    object.topic.custom_fields[DiscourseModCategories::TOPIC_REPLY_PROMPT_TL_FIELD]
  end
  add_to_serializer(:topic_view, :mod_topic_pinned_post_id) do
    object.topic.custom_fields[DiscourseModCategories::TOPIC_PINNED_POST_FIELD]
  end
  add_to_serializer(:topic_view, :mod_topic_require_reply_approval) do
    !!object.topic.custom_fields[DiscourseModCategories::TOPIC_REQUIRE_REPLY_APPROVAL_FIELD]
  end

  # The per-topic prompt checklist — surfaced on the topic so the
  # frontend editor modal can read its current state, and the gate can
  # detect an active checklist without an extra round trip.
  add_to_serializer(:topic_view, :mod_topic_prompt_checklist) do
    raw = object.topic.custom_fields[DiscourseModCategories::TOPIC_PROMPT_CHECKLIST_FIELD]
    raw =
      begin
        JSON.parse(raw)
      rescue StandardError
        nil
      end if raw.is_a?(String)
    next nil unless raw.is_a?(Hash)
    items = raw["items"].is_a?(Array) ? raw["items"] : []
    mode = raw["mode"].to_s
    mode = "checklist" if %w[statement checklist].exclude?(mode)
    frequency = raw["frequency"].to_s
    frequency = "once" if %w[once every_reply].exclude?(frequency)
    max_tl = raw.key?("max_tl") ? raw["max_tl"].to_i : 4
    # An inactive (mode=statement with blank statement, or mode=checklist
    # with no items) config serializes to null — the gate skips it anyway.
    if mode == "statement"
      next nil if raw["statement"].to_s.strip.empty?
    else
      next nil if items.empty?
    end
    {
      version: raw["version"].to_i,
      mode: mode,
      statement: raw["statement"].to_s,
      items: items,
      frequency: frequency,
      max_tl: max_tl,
      button_label: raw["button_label"].to_s,
      updated_at: raw["updated_at"],
    }
  end

  # The private moderator note is only ever serialized to staff, so a
  # regular user's topic JSON never contains it.
  add_to_serializer(
    :topic_view,
    :mod_topic_private_note,
    include_condition: -> { scope.is_staff? },
  ) { object.topic.custom_fields[DiscourseModCategories::TOPIC_PRIVATE_NOTE_FIELD] }
  add_to_serializer(
    :topic_view,
    :mod_topic_private_note_position,
    include_condition: -> { scope.is_staff? },
  ) { object.topic.custom_fields[DiscourseModCategories::TOPIC_PRIVATE_NOTE_POSITION_FIELD] }
  # Who set the note — staff only, so the note can be shown like a post.
  add_to_serializer(
    :topic_view,
    :mod_topic_private_note_author,
    include_condition: -> { scope.is_staff? },
  ) do
    user_id = object.topic.custom_fields[DiscourseModCategories::TOPIC_PRIVATE_NOTE_USER_FIELD]
    user = user_id && User.find_by(id: user_id)
    { username: user.username, name: user.name, avatar_template: user.avatar_template } if user
  end
  add_to_serializer(
    :topic_view,
    :mod_topic_private_note_created_at,
    include_condition: -> { scope.is_staff? },
  ) { object.topic.custom_fields[DiscourseModCategories::TOPIC_PRIVATE_NOTE_CREATED_AT_FIELD] }
  # The thread of staff replies to the note.
  add_to_serializer(
    :topic_view,
    :mod_topic_private_note_replies,
    include_condition: -> { scope.is_staff? },
  ) do
    raw = object.topic.custom_fields[DiscourseModCategories::TOPIC_PRIVATE_NOTE_REPLIES_FIELD]
    entries = raw.is_a?(Array) ? raw : []
    entries.map do |entry|
      author = entry["user_id"] && User.find_by(id: entry["user_id"])
      {
        id: entry["id"].presence || SecureRandom.hex(8),
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

  # Staff who have rendered the mod-note panel on this topic — used by the
  # "👁 Viewed by N" pill at the bottom of the panel. Newest viewer last,
  # so the UI can show the most recent at the top when reversed.
  add_to_serializer(
    :topic_view,
    :mod_topic_note_viewers,
    include_condition: -> { scope.is_staff? },
  ) do
    raw = object.topic.custom_fields[DiscourseModCategories::TOPIC_NOTE_VIEWERS_FIELD]
    Array(raw).map do |entry|
      {
        user_id: entry["user_id"],
        username: entry["username"],
        name: entry["name"],
        avatar_template: entry["avatar_template"],
        viewed_at: entry["viewed_at"],
      }
    end
  end

  # Unread moderator-note count, for the staff member's user-menu tab. Derived
  # from the same unread Notification rows that drive the standard avatar
  # bell dot, so reading a mod-note from the bell decrements this count and
  # opening the shield tab (which marks the rows read) decrements the bell.
  add_to_serializer(:current_user, :mod_note_unread_count) do
    next 0 unless object.staff?

    ::Notification
      .where(user_id: object.id, notification_type: ::Notification.types[:custom], read: false)
      .where("data LIKE ?", "%\"mod_note\":true%")
      .count
  end

  # First-post checklist: the single checklist the current user most needs
  # to accept before posting, or nil so the frontend can skip the modal.
  # The owed-checklist computation lives in
  # `DiscourseModCategories.owed_checklist_for` so the serializer and the
  # `/checklist/owed` endpoint share one implementation.
  #
  # NOTE: the bootstrapped current-user payload only carries the value as
  # of the page load. The frontend re-fetches `/checklist/owed` when the
  # composer opens so a mid-session version bump is still gated.
  add_to_serializer(:current_user, :mod_first_post_checklist) do
    DiscourseModCategories.owed_checklist_for(object)
  end

  # Per-topic reply approval: when a moderator flags a topic, replies to it
  # are routed to the review queue instead of being published directly.
  # This is the per-topic analogue of a category's require_reply_approval.
  NewPostManager.add_handler do |manager|
    topic_id = manager.args[:topic_id]
    next nil if topic_id.blank?

    topic = Topic.find_by(id: topic_id)
    next nil unless topic
    next nil unless topic.custom_fields[DiscourseModCategories::TOPIC_REQUIRE_REPLY_APPROVAL_FIELD]

    # Staff (and anyone who can review the topic) post without approval.
    next nil if manager.user&.guardian&.can_review_topic?(topic)

    manager.enqueue("mod_topic_requires_reply_approval")
  end

  # Expose the per-category prompt on every serialized category so the
  # composer can read it for the category a new topic is being created in.
  Site.preloaded_category_custom_fields << DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_FIELD
  Site.preloaded_category_custom_fields << DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_TL_FIELD
  add_to_serializer(:basic_category, :mod_category_new_topic_prompt) do
    object.custom_fields[DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_FIELD]
  end

  # ---------------------------------------------------------------------
  # Moderator whisper
  # ---------------------------------------------------------------------

  # Merge new non-staff participant ids into a topic's cumulative whisper-
  # participant list and persist immediately (the topic is already saved).
  merge_whisper_participants =
    lambda do |topic, new_ids|
      existing =
        Array(topic.custom_fields[DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD]).map(
          &:to_i
        )
      merged = (existing + new_ids.map(&:to_i)).reject { |i| i <= 0 }.uniq
      next if merged.sort == existing.sort

      topic.custom_fields[DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD] = merged
      topic.save_custom_fields(true)
    end

  register_post_custom_field_type(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD, :json)
  register_post_custom_field_type(DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD, :json)
  register_post_custom_field_type(DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD, :json)
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD, :json)
  add_permitted_post_create_param(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD, :array)
  add_permitted_post_create_param(DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD, :array)
  add_permitted_post_create_param(DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD, :array)
  # Permitted as a scalar (:string) — `add_permitted_post_create_param` only
  # special-cases :array/:hash, and an unrecognized type would drop the param
  # entirely. The value arrives as the string "true"/"false" and is cast with
  # ActiveModel::Type::Boolean in the before_create_post handler below.
  add_permitted_post_create_param(DiscourseModCategories::POST_WHISPER_ARMED_PARAM, :string)

  # Expose the topic's cumulative whisper participants so the composer can
  # tell whether the current (non-staff) user may whisper back.
  add_to_serializer(:topic_view, :mod_whisper_participant_ids) do
    raw = object.topic.custom_fields[DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD]
    Array(raw).map(&:to_i)
  end

  # Filter whispers out of the topic stream for viewers who are not in the
  # audience. Staff bypass this; the Guardian override is the parallel gate.
  TopicView.apply_custom_default_scope do |scope, tv|
    DiscourseModCategories::WhisperQueryFilter.apply(scope, tv.guardian&.user)
  end

  # Mark a new post as a whisper BEFORE PostCreator saves it, so the custom
  # field is persisted atomically by HasCustomFields' after_save callback.
  #
  # The `mod_whisper` boolean armed flag is THE gate: a whisper is created
  # only when the composer explicitly armed one. Whisper-ness is no longer
  # inferred from the target count or from topic-participant membership — an
  # empty target list is a valid staff-only whisper, and a participant's
  # normal (un-armed) reply stays a normal public post.
  on(:before_create_post) do |post, opts|
    next unless SiteSetting.mod_whisper_enabled

    armed =
      ::ActiveModel::Type::Boolean.new.cast(opts[DiscourseModCategories::POST_WHISPER_ARMED_PARAM])
    next unless armed

    normalize_ids =
      lambda do |raw|
        Array(raw)
          .map { |v| v.is_a?(Numeric) || v.is_a?(String) ? v.to_i : 0 }
          .reject { |i| i <= 0 }
          .uniq
          .first(DiscourseModCategories::MAX_WHISPER_TARGETS)
      end

    requested_ids = normalize_ids.call(opts[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD])
    requested_group_ids =
      normalize_ids.call(opts[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD])
    requested_badge_ids =
      normalize_ids.call(opts[DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD])

    author = post.user
    topic = post.topic
    next unless author && topic

    if author.staff?
      # Staff whisper: keep only ids that map to real users / real groups /
      # real badges. An EMPTY user AND group AND badge list is valid and
      # means a staff-only whisper.
      valid_ids = ::User.where(id: requested_ids).pluck(:id)
      valid_group_ids = ::Group.where(id: requested_group_ids).pluck(:id)
      valid_badge_ids = ::Badge.where(id: requested_badge_ids).pluck(:id)

      post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD] = valid_ids
      post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD] = valid_group_ids
      post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD] = valid_badge_ids

      # Record the non-staff targets (explicit users + current badge holders)
      # as cumulative topic participants so they keep visibility on later
      # whispers in the topic even after a badge revoke.
      non_staff_ids = ::User.where(id: valid_ids).where(admin: false, moderator: false).pluck(:id)
      if valid_badge_ids.any?
        non_staff_ids +=
          ::User
            .joins(:user_badges)
            .where(user_badges: { badge_id: valid_badge_ids })
            .where(admin: false, moderator: false)
            .distinct
            .pluck(:id)
        non_staff_ids.uniq!
      end
      merge_whisper_participants.call(topic, non_staff_ids) if non_staff_ids.any?
    else
      # Non-staff: only an existing topic whisper participant may whisper,
      # and only ever staff-only (forced empty targets). A non-participant
      # who somehow arms a whisper does not whisper (defense in depth).
      participant_ids =
        Array(topic.custom_fields[DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD]).map(
          &:to_i
        )
      next if participant_ids.exclude?(author.id)

      post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD] = []
      post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD] = []
      post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD] = []
    end
  end

  # Notify the whisper audience once the post exists. Staff-authored whispers
  # notify the chosen targets; a non-staff whisper-back notifies all staff.
  on(:post_created) do |post, opts, user|
    next unless SiteSetting.mod_whisper_enabled
    next unless post.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)

    target_ids =
      Array(post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD]).map(&:to_i)
    target_group_ids =
      Array(post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD]).map(
        &:to_i
      )
    target_badge_ids =
      Array(post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD]).map(
        &:to_i
      )

    topic = post.topic

    # Roll back Topic#highest_post_number so non-audience viewers do not see
    # a topic-list "+1 unread" badge for a whisper they can't read. The
    # :listable_topic serializer override adds the bump back for audience
    # members on serialization, so they still see the badge. Runs for EVERY
    # whisper (including staff-only whisper-backs with no recipients).
    #
    # Also stamp the latest non-whisper post's created_at into a topic custom
    # field, which the :topic_query_create_list_topics modifier below uses
    # to sort the /latest list audience-aware: audience members see the
    # topic bumped to the whisper time (Topic#bumped_at), non-audience
    # users see it at the non-whisper time. Topic#bumped_at itself is left
    # alone so the DB column keeps reflecting the actual latest activity.
    if topic
      non_whisper_scope =
        ::Post
          .where(topic_id: topic.id, deleted_at: nil)
          .where.not(
            id:
              ::PostCustomField.where(
                name: DiscourseModCategories::POST_WHISPER_TARGETS_FIELD,
              ).select(:post_id),
          )
      non_whisper_max = non_whisper_scope.maximum(:post_number) || 0
      non_whisper_created_at = non_whisper_scope.maximum(:created_at)

      if non_whisper_max > 0 && non_whisper_max < topic.highest_post_number
        ::Topic.where(id: topic.id).update_all(highest_post_number: non_whisper_max)
      end

      if non_whisper_created_at
        topic.custom_fields[
          DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD
        ] = non_whisper_created_at.iso8601
        topic.save_custom_fields(true)
      end
    end

    recipient_ids =
      if user&.staff?
        ids = target_ids.dup
        ids +=
          ::GroupUser.where(group_id: target_group_ids).pluck(:user_id) if target_group_ids.any?
        ids +=
          ::UserBadge.where(badge_id: target_badge_ids).pluck(:user_id) if target_badge_ids.any?
        ids
      else
        ::User.where(admin: true).or(::User.where(moderator: true)).pluck(:id)
      end
    recipient_ids = recipient_ids.uniq - [post.user_id]
    next if recipient_ids.empty?

    data = {
      topic_title: topic&.title,
      display_username: user&.username,
      # Stable marker so MessagesController#mark_topic_notifications_seen
      # can scope its read-flip to OUR notifications without touching
      # other plugins' custom notifications attached to the same topic.
      mod_whisper: true,
      original_post_id: post.id,
      original_post_type: post.post_type,
    }.to_json

    recipient_ids.each do |recipient_id|
      Notification.create!(
        notification_type: Notification.types[:custom],
        user_id: recipient_id,
        topic_id: topic&.id,
        post_number: post.post_number,
        data: data,
      )
    end

    # Dedupe: PostAlerter runs asynchronously and creates standard
    # :replied / :posted / :quoted / :mentioned notifications for the
    # topic author, watchers, and mentioned users. If any of those users
    # are also in our whisper audience, they see TWO bell rows for the
    # same post — one custom whisper from us, one core reply from
    # PostAlerter. We schedule a 5-second delayed cleanup that removes
    # the core duplicates only for users who got our custom whisper.
    # Done as a delayed job because PostAlerter runs in its own Sidekiq
    # job after :post_created, so we'd race it if we cleaned up inline.
    if topic && post.persisted?
      ::Jobs.enqueue_in(
        5.seconds,
        :dedupe_mod_whisper_notifications,
        post_id: post.id,
        recipient_ids: recipient_ids,
      )
    end
  end

  # Audience-aware ordering on the topic list. The DB column Topic#bumped_at
  # is left at the actual latest-activity time (including whispers), and the
  # `on(:post_created)` hook above writes the latest non-whisper post's
  # created_at into a topic custom field. This modifier patches the
  # `/latest` (and friends) topic-list query to use that custom field as
  # the effective sort key for users who are NOT in the topic's whisper
  # audience, while audience members keep the live `bumped_at`.
  #
  # Audience criterion in this modifier: staff OR the user_id appears in
  # the topic's `mod_whisper_participant_ids` custom field (the cumulative
  # whisper-conversation participants of the topic). Explicit per-whisper
  # user/group/badge targets are folded into the participants list by the
  # composer flow (see TOPIC_WHISPER_PARTICIPANTS_FIELD writes elsewhere
  # in this file), so this single check covers all four audience kinds.
  #
  # The modifier is wrapped in `rescue StandardError` so any breakage from
  # a future Discourse upgrade (renamed hook, query shape change, schema
  # change) falls back to the unmodified scope instead of breaking
  # /latest entirely. The fallback is Option B — whispers bump for
  # everyone — which is annoying but recoverable. CI exercises the path
  # via specs in whisper_unread_badge_spec.rb so we'd see breakage early.
  register_modifier(:topic_query_create_list_topics) do |scope, _options, topic_query|
    begin
      user = topic_query.user

      # Staff are in the audience for every whisper — sort by live bumped_at.
      next scope if user&.staff?

      user_id = user&.id
      nwba_field = DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD
      participants_field = DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD

      connection = ::ActiveRecord::Base.connection
      nwba_field_quoted = connection.quote(nwba_field)
      participants_field_quoted = connection.quote(participants_field)

      scope =
        scope.joins(
          "LEFT OUTER JOIN topic_custom_fields nwba " \
            "ON nwba.topic_id = topics.id AND nwba.name = #{nwba_field_quoted}",
        ).joins(
          "LEFT OUTER JOIN topic_custom_fields part " \
            "ON part.topic_id = topics.id AND part.name = #{participants_field_quoted}",
        )

      is_audience_sql =
        if user_id
          # The participants field is registered as :json, so its `value`
          # column holds a JSON-serialized array of integer user_ids.
          # `value::jsonb @> '<id>'::jsonb` is the safe containment check:
          # `[5,7]::jsonb @> 5::jsonb` is true, no false positives from
          # substring overlap (e.g., 15 doesn't match 5). The LIKE guard
          # skips obviously-malformed legacy rows so the ::jsonb cast
          # cannot raise mid-query.
          "(part.value IS NOT NULL AND part.value <> '' " \
            "AND part.value LIKE '[%]' " \
            "AND part.value::jsonb @> '#{user_id.to_i}'::jsonb)"
        else
          "FALSE"
        end

      # The regex guard `~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'` ensures the
      # ::timestamp cast only runs on values that LOOK like ISO8601 dates,
      # so a corrupted or human-edited custom-field value (e.g. legacy
      # data, a typo, the literal string "not-a-time") falls through to
      # topics.bumped_at instead of blowing up the entire /latest query.
      # The outer `rescue StandardError` below is a last-resort net for
      # Ruby-level errors raised while BUILDING the modifier scope (e.g.
      # a future Discourse refactor changing AR method signatures); it
      # cannot catch SQL execution errors because the reorder is lazy
      # and runs after the modifier returns. The regex guard is the
      # primary defense against bad data.
      effective_bumped_at = <<~SQL.squish
        CASE
          WHEN #{is_audience_sql} THEN topics.bumped_at
          WHEN nwba.value IS NOT NULL
               AND nwba.value <> ''
               AND nwba.value ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
            THEN nwba.value::timestamp
          ELSE topics.bumped_at
        END
      SQL

      scope.reorder(::Arel.sql("(#{effective_bumped_at}) DESC, topics.id DESC"))
    rescue StandardError => e
      ::Rails.logger.warn(
        "[jtech-tools] topic_query audience-aware sort fell back: #{e.class}: #{e.message}",
      )
      scope
    end
  end

  add_to_serializer(:post, :mod_is_whisper) do
    object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end
  add_to_serializer(:post, :include_mod_is_whisper?) { SiteSetting.mod_whisper_enabled }

  add_to_serializer(:post, :mod_whisper_target_user_ids) do
    Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD]).map(&:to_i)
  end
  add_to_serializer(:post, :include_mod_whisper_target_user_ids?) do
    SiteSetting.mod_whisper_enabled &&
      object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end

  add_to_serializer(:post, :mod_whisper_target_group_ids) do
    Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD]).map(
      &:to_i
    )
  end
  add_to_serializer(:post, :include_mod_whisper_target_group_ids?) do
    SiteSetting.mod_whisper_enabled &&
      object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end

  add_to_serializer(:post, :mod_whisper_target_groups) do
    ids =
      Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD]).map(
        &:to_i
      )
    ::Group.where(id: ids).map { |g| { id: g.id, name: g.name } }
  end
  add_to_serializer(:post, :include_mod_whisper_target_groups?) do
    SiteSetting.mod_whisper_enabled &&
      object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end

  add_to_serializer(:post, :mod_whisper_target_badge_ids) do
    Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD]).map(
      &:to_i
    )
  end
  add_to_serializer(:post, :include_mod_whisper_target_badge_ids?) do
    SiteSetting.mod_whisper_enabled &&
      object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end

  add_to_serializer(:post, :mod_whisper_target_badges) do
    ids =
      Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD]).map(
        &:to_i
      )
    ::Badge.where(id: ids).map { |b| { id: b.id, name: b.display_name } }
  end
  add_to_serializer(:post, :include_mod_whisper_target_badges?) do
    SiteSetting.mod_whisper_enabled &&
      object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end

  add_to_serializer(:post, :mod_whisper_targets) do
    ids =
      Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD]).map(&:to_i)
    ::User
      .where(id: ids)
      .map { |u| { id: u.id, username: u.username, avatar_template: u.avatar_template } }
  end
  add_to_serializer(:post, :include_mod_whisper_targets?) do
    SiteSetting.mod_whisper_enabled &&
      object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end

  # A whisper with no user targets AND no group targets AND no badge
  # targets is a staff-only whisper-back.
  add_to_serializer(:post, :mod_whisper_is_staff_only) do
    Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD]).empty? &&
      Array(
        object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD],
      ).empty? &&
      Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD]).empty?
  end
  add_to_serializer(:post, :include_mod_whisper_is_staff_only?) do
    SiteSetting.mod_whisper_enabled &&
      object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end

  add_to_serializer(:post, :mod_whisper_author_is_staff) { !!object.user&.staff? }
  add_to_serializer(:post, :include_mod_whisper_author_is_staff?) do
    SiteSetting.mod_whisper_enabled &&
      object.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
  end

  add_to_serializer(:basic_category, :mod_category_new_topic_prompt_max_tl) do
    object.custom_fields[DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_TL_FIELD]
  end

  # Audience-aware highest_post_number for the topic list. Returns the max
  # post_number in the topic that the CURRENT user can see — whispers are
  # excluded for non-audience viewers and included for the audience (staff,
  # explicit targets, group targets, topic participants). This is what makes
  # the topic-list `(highest - last_read)` math audience-aware: non-audience
  # viewers never see a badge bump from a whisper they can't read.
  add_to_serializer(:listable_topic, :highest_post_number) do
    raw = object.highest_post_number
    next raw unless SiteSetting.mod_whisper_enabled

    visible_max = DiscourseModCategories.whisper_audience_max_post_number(object, scope&.user)
    visible_max || raw
  end

  # Audience-aware bumped_at for the topic list's "Activity" column. The
  # topic-list query modifier already SORTS non-audience viewers by the
  # non-whisper bump time, but the displayed Activity column read the raw
  # `topics.bumped_at` and showed e.g. "5m" for a whisper they can't see.
  # Mirror the same audience check here so the displayed time matches the
  # sort position: audience members (staff + topic participants) see the
  # actual bump time; non-audience viewers see the non-whisper bump time
  # stored in the custom field. Falls through to raw on missing/malformed
  # field values so an upgrade to a topic without the stamp still works.
  add_to_serializer(:listable_topic, :bumped_at) do
    raw = object.bumped_at
    next raw unless SiteSetting.mod_whisper_enabled

    user = scope&.user
    next raw if user&.staff?

    # All custom-field access wrapped together: HasCustomFields::PreloadedProxy
    # raises NotPreloadedError if `add_preloaded_topic_list_custom_field`
    # registrations above haven't taken effect (e.g. early in boot, or
    # after a Discourse release reshapes the preloader). Falling through
    # to `raw` keeps /latest responsive in that case — the worst outcome
    # is the pre-fix "stranger sees the whisper time" display, which is
    # recoverable on the next request.
    begin
      participants = object.custom_fields[DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD]
      next raw if user && participants.is_a?(Array) && participants.map(&:to_i).include?(user.id)

      nwba = object.custom_fields[DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD]
      next raw if nwba.blank?

      parsed = ::Time.zone.parse(nwba.to_s)
      parsed || raw
    rescue StandardError
      raw
    end
  end
end
