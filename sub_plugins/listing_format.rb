# frozen_string_literal: true
# Jtech sub-plugin: Listing format — sale threads where every post is a
# listing, and buyers reach the seller through REQ-PM instead of replying.
#
# In the topics listed in listing_format_topics, a new post must have each
# section from listing_format_fields ("### ITEM" with the item under it),
# and may not link to other sites: only email addresses, phone numbers and
# the forum itself. A post that breaks either rule is turned away with the
# reason, before it's saved, so nothing is hidden or deleted afterwards.
# That also turns away comments ("still available?"): each listing has the
# seller's REQ-PM button instead, and its Reply button is gone.
#
# Posts written before a topic was listed are left alone. Editing one is
# checked against what it already had: an edit can't add an outside link
# or take out a field the post had, but it doesn't have to add the rest.
#
# A listing shows whether it's still available; the seller and staff can
# mark it sold (see ListingsController).

register_asset "stylesheets/listing-format.scss"

module ::DiscourseListingFormat
  def self.enabled?
    SiteSetting.jtech_enabled && SiteSetting.listing_format_enabled
  end

  # Whether `user` writing in `topic_id` has to follow the format.
  def self.applies?(topic_id, user)
    enabled? && topic_id.present? && Checker.topic_ids.include?(topic_id) && !exempt?(user)
  end

  def self.exempt?(user)
    return true if user.nil? || user.is_system_user?
    user.in_any_groups?(SiteSetting.listing_format_exempt_groups_map)
  end

  SOLD_FIELD = "listing_sold"

  # A post in a listing topic other than the topic's own opening post.
  def self.listing?(post)
    enabled? && post.post_number > 1 && Checker.topic_ids.include?(post.topic_id)
  end

  def self.can_mark_sold?(post, guardian)
    guardian.user.present? && (post.user_id == guardian.user.id || guardian.is_staff?)
  end
end

require_relative "../lib/discourse_listing_format/checker"

after_initialize do
  register_post_custom_field_type(DiscourseListingFormat::SOLD_FIELD, :boolean)

  # Loaded with the topic's posts in one query, for the sold mark below.
  topic_view_post_custom_fields_allowlister do |_user, topic|
    if DiscourseListingFormat.enabled? &&
         DiscourseListingFormat::Checker.topic_ids.include?(topic&.id)
      [DiscourseListingFormat::SOLD_FIELD]
    else
      []
    end
  end

  # Whether a listing is sold, for everyone who can see it.
  add_to_serializer(
    :post,
    :listing_sold,
    include_condition: -> { DiscourseListingFormat.listing?(object) },
  ) { post_custom_fields[DiscourseListingFormat::SOLD_FIELD] == true }

  # Runs on create and on every revision; core's own validators run
  # alongside. Skipped when nothing changed in the text (rebakes, moves,
  # hiding, locking) and when the caller asked to skip validations.
  validate(:post, :validate_listing_format) do
    next if skip_validation
    next unless will_save_change_to_raw?
    next unless post_type == Post.types[:regular]
    next unless DiscourseListingFormat.applies?(topic_id, acting_user)

    previous = new_record? ? nil : raw_was
    DiscourseListingFormat::Checker
      .new(raw, previous: previous, topic_id: topic_id)
      .problems
      .each { |message| errors.add(:base, message) }
  end

  # Tells the client to show REQ-PM on posts and leave out their
  # Reply buttons. Says nothing the topic page doesn't already show.
  add_to_serializer(
    :topic_view,
    :listing_format_topic,
    include_condition: -> do
      DiscourseListingFormat.enabled? &&
        DiscourseListingFormat::Checker.topic_ids.include?(object.topic.id)
    end,
  ) { true }

  # The sections and the pictures section, so listings show as cards for
  # everyone, staff and visitors included. The format itself, nothing more.
  add_to_serializer(
    :topic_view,
    :listing_format_card,
    include_condition: -> do
      DiscourseListingFormat.enabled? &&
        DiscourseListingFormat::Checker.topic_ids.include?(object.topic.id)
    end,
  ) do
    {
      sections: DiscourseListingFormat::Checker.fields,
      images: DiscourseListingFormat::Checker.editor_field,
    }
  end

  # The fields for the reply composer's form. Only sent where the format
  # applies to the person viewing.
  add_to_serializer(
    :topic_view,
    :listing_format_fields,
    include_condition: -> { DiscourseListingFormat.applies?(object.topic.id, scope.user) },
  ) { DiscourseListingFormat::Checker.fields }

  # Options to pick from for some sections (condition, pickup/shipping).
  add_to_serializer(
    :topic_view,
    :listing_format_choices,
    include_condition: -> { DiscourseListingFormat.applies?(object.topic.id, scope.user) },
  ) { DiscourseListingFormat::Checker.choices }

  # Which of those may be left empty.
  add_to_serializer(
    :topic_view,
    :listing_format_optional_fields,
    include_condition: -> { DiscourseListingFormat.applies?(object.topic.id, scope.user) },
  ) { DiscourseListingFormat::Checker.optional_fields }

  # Which of those the editor fills (pictures), so it gets no box of its
  # own. Left out when it isn't one of the fields.
  add_to_serializer(
    :topic_view,
    :listing_format_editor_field,
    include_condition: -> do
      DiscourseListingFormat.applies?(object.topic.id, scope.user) &&
        DiscourseListingFormat::Checker.editor_field.present?
    end,
  ) { DiscourseListingFormat::Checker.editor_field }
end
