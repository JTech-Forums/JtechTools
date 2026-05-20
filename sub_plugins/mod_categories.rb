# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `discourse-mod/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.

require_relative "../lib/discourse_mod_categories/guardian_extensions"
require_relative "../lib/discourse_mod_categories/whisper_query_filter"

register_asset "stylesheets/topic-footer-message.scss"
register_asset "stylesheets/whisper.scss"
register_asset "stylesheets/mod-note-header-pip.scss"
register_svg_icon "list-check"
register_svg_icon "shield-halved"
register_svg_icon "user-plus"
register_svg_icon "pencil"
register_svg_icon "trash-can"

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
  TOPIC_WHISPER_PARTICIPANTS_FIELD = "mod_whisper_participant_ids"
  MAX_WHISPER_TARGETS = 10
  # Explicit boolean armed flag sent by the composer. A boolean survives
  # form-encoding even when the target id array is empty, so it — not the
  # target count — is the single source of truth for "this post is a whisper".
  POST_WHISPER_ARMED_PARAM = "mod_whisper"

  class Engine < ::Rails::Engine
    engine_name "discourse_mod_categories"
    isolate_namespace DiscourseModCategories
  end
end

after_initialize do
  reloadable_patch { ::Guardian.prepend(DiscourseModCategories::GuardianExtensions) }

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

  # Unread moderator-note count, for the staff member's user-menu tab.
  add_to_serializer(:current_user, :mod_note_unread_count) do
    next 0 unless object.staff?

    seen_at =
      Array(object.custom_fields[DiscourseModCategories::USER_NOTES_SEEN_FIELD])
        .compact
        .max
        .presence || "1970-01-01T00:00:00Z"

    TopicCustomField
      .where(name: DiscourseModCategories::TOPIC_PRIVATE_NOTE_ACTIVITY_FIELD)
      .where("value > ?", seen_at)
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
  register_topic_custom_field_type(DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD, :json)
  add_permitted_post_create_param(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD, :array)
  add_permitted_post_create_param(DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD, :array)
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

    author = post.user
    topic = post.topic
    next unless author && topic

    if author.staff?
      # Staff whisper: keep only ids that map to real users / real groups. An
      # EMPTY user AND group list is valid and means a staff-only whisper.
      valid_ids = ::User.where(id: requested_ids).pluck(:id)
      valid_group_ids = ::Group.where(id: requested_group_ids).pluck(:id)

      post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD] = valid_ids
      post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD] = valid_group_ids

      # Record the non-staff targets as cumulative topic participants.
      non_staff_ids = ::User.where(id: valid_ids).where(admin: false, moderator: false).pluck(:id)
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
    end
  end

  # Notify the whisper audience once the post exists. Staff-authored whispers
  # notify the chosen targets; a non-staff whisper-back notifies all staff.
  on(:post_created) do |post, opts, user|
    next unless SiteSetting.mod_whisper_enabled
    next unless post.custom_fields.key?(DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)

    target_ids =
      Array(post.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD]).map(&:to_i)

    recipient_ids =
      if user&.staff?
        target_ids
      else
        ::User.where(admin: true).or(::User.where(moderator: true)).pluck(:id)
      end
    recipient_ids = recipient_ids.uniq - [post.user_id]
    next if recipient_ids.empty?

    topic = post.topic
    data = {
      topic_title: topic&.title,
      display_username: user&.username,
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

  # A whisper with no user targets AND no group targets is a staff-only
  # whisper-back.
  add_to_serializer(:post, :mod_whisper_is_staff_only) do
    Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD]).empty? &&
      Array(object.custom_fields[DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD]).empty?
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
end
