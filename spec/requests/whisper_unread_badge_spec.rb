# frozen_string_literal: true

require "rails_helper"

# Verifies the audience-aware unread-badge behavior for whisper posts:
#
# * Topic#highest_post_number is rolled back after a whisper is created so a
#   non-audience viewer's topic-list badge is not bumped.
# * The :listable_topic serializer adds the bump back for audience members
#   (staff, explicit user targets, group targets, cumulative participants).
RSpec.describe "Whisper unread badge" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:target, :user)
  fab!(:participant, :user)
  fab!(:stranger, :user)
  fab!(:group_member, :user)
  fab!(:whisper_group) { Fabricate(:group, name: "whisper_squad") }
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: author) }
  fab!(:regular_reply) { Fabricate(:post, topic: topic, user: author) }
  fab!(:whisper_post) { Fabricate(:post, topic: topic, user: moderator) }

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:groups_field) { DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD }
  let(:participants_field) { DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    Group.refresh_automatic_groups!

    # Mark the post a whisper to target + participant. Triggers the same
    # rollback the post_created handler would, since the spec writes the
    # custom field directly (no PostCreator path).
    whisper_post.custom_fields[targets_field] = [target.id]
    whisper_post.save_custom_fields(true)

    topic.custom_fields[participants_field] = [target.id, participant.id]
    topic.save_custom_fields(true)
  end

  describe "DiscourseModCategories.whisper_audience_max_post_number" do
    it "returns the whisper's post_number for an explicit user target" do
      expect(DiscourseModCategories.whisper_audience_max_post_number(topic, target)).to eq(
        whisper_post.post_number,
      )
    end

    it "returns the whisper's post_number for a cumulative topic participant" do
      expect(DiscourseModCategories.whisper_audience_max_post_number(topic, participant)).to eq(
        whisper_post.post_number,
      )
    end

    it "returns the whisper's post_number for staff" do
      expect(DiscourseModCategories.whisper_audience_max_post_number(topic, admin)).to eq(
        whisper_post.post_number,
      )
      expect(DiscourseModCategories.whisper_audience_max_post_number(topic, moderator)).to eq(
        whisper_post.post_number,
      )
    end

    it "returns the highest non-whisper post_number for a non-audience user" do
      expect(DiscourseModCategories.whisper_audience_max_post_number(topic, stranger)).to eq(
        regular_reply.post_number,
      )
    end

    it "returns the highest non-whisper post_number for anonymous viewers" do
      expect(DiscourseModCategories.whisper_audience_max_post_number(topic, nil)).to eq(
        regular_reply.post_number,
      )
    end

    it "honors group-target audience" do
      whisper_group.add(group_member)
      whisper_post.custom_fields[targets_field] = []
      whisper_post.custom_fields[groups_field] = [whisper_group.id]
      whisper_post.save_custom_fields(true)

      expect(DiscourseModCategories.whisper_audience_max_post_number(topic, group_member)).to eq(
        whisper_post.post_number,
      )
    end
  end

  describe "topic-list highest_post_number serialization" do
    # The listable_topic serializer override returns the per-user audience-aware
    # max so the (highest - last_read) topic-list math is audience-aware.
    it "reports the whisper as the highest post number for an audience member" do
      sign_in(target)
      get "/latest.json"
      topic_json = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == topic.id }
      expect(topic_json["highest_post_number"]).to eq(whisper_post.post_number)
    end

    it "reports the prior non-whisper post as the highest for a non-audience user" do
      sign_in(stranger)
      get "/latest.json"
      topic_json = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == topic.id }
      expect(topic_json["highest_post_number"]).to eq(regular_reply.post_number)
    end

    it "reports the whisper as the highest for staff" do
      sign_in(admin)
      get "/latest.json"
      topic_json = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == topic.id }
      expect(topic_json["highest_post_number"]).to eq(whisper_post.post_number)
    end
  end

  describe "post_created rollback" do
    before { SiteSetting.min_post_length = 5 }

    it "rolls Topic#highest_post_number back to the last non-whisper post when a whisper is created" do
      sign_in(moderator)
      # The topic already has op(1), regular_reply(2), whisper_post(3).
      # Create a NEW whisper via the real PostCreator path so the on(:post_created)
      # rollback runs.
      post "/posts.json",
           params: {
             :topic_id => topic.id,
             :raw => "Yet another whisper body long enough to be valid.",
             DiscourseModCategories::POST_WHISPER_ARMED_PARAM => true,
             DiscourseModCategories::POST_WHISPER_TARGETS_FIELD => [target.id],
           }
      expect(response.status).to eq(200)

      topic.reload
      expect(topic.highest_post_number).to eq(regular_reply.post_number)
    end

    it "stamps non_whisper_bumped_at into a topic custom field on whisper creation" do
      # Backdate BOTH non-whisper posts so the max(:created_at) is
      # deterministically regular_reply (15 min ago) — op was fabricated
      # at ~now, so without the older backdate it would win the max() and
      # the stamp wouldn't match what the assertion expects.
      op.update_columns(created_at: 30.minutes.ago)
      regular_reply.update_columns(created_at: 15.minutes.ago)

      sign_in(moderator)
      post "/posts.json",
           params: {
             :topic_id => topic.id,
             :raw => "Whisper body long enough to satisfy min_post_length.",
             DiscourseModCategories::POST_WHISPER_ARMED_PARAM => true,
             DiscourseModCategories::POST_WHISPER_TARGETS_FIELD => [target.id],
           }
      expect(response.status).to eq(200)

      stamped =
        topic.reload.custom_fields[DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD].to_s
      expect(stamped).not_to be_empty
      expect(Time.zone.parse(stamped)).to be_within(1.second).of(regular_reply.reload.created_at)
    end
  end

  describe "audience-aware /latest ordering" do
    fab!(:public_topic, :topic)
    fab!(:public_topic_op) { Fabricate(:post, topic: public_topic, user: author) }

    before do
      # Pin a clear ordering: the whispered topic was bumped at the whisper
      # time (30 min ago via fabrication), the public topic is more recent.
      # An audience member should see the whispered topic at the top — the
      # whisper IS the latest activity for them. A non-audience viewer
      # should see the public topic first because, for them, the whispered
      # topic's effective bump is the older regular_reply.
      regular_reply.update_columns(created_at: 1.hour.ago)
      ::Topic.where(id: topic.id).update_all(
        bumped_at: 5.minutes.ago,
        last_posted_at: 5.minutes.ago,
      )
      ::Topic.where(id: public_topic.id).update_all(
        bumped_at: 30.minutes.ago,
        last_posted_at: 30.minutes.ago,
      )
      # Simulate the on(:post_created) stamp.
      topic.custom_fields[
        DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD
      ] = regular_reply.created_at.iso8601
      topic.save_custom_fields(true)
    end

    def latest_topic_ids(as_user)
      sign_in(as_user)
      get "/latest.json"
      expect(response.status).to eq(200)
      response.parsed_body["topic_list"]["topics"].map { |t| t["id"] }
    end

    it "keeps the whispered topic at the top of /latest for staff" do
      ids = latest_topic_ids(admin)
      expect(ids.index(topic.id)).to be < ids.index(public_topic.id)
    end

    it "keeps the whispered topic at the top of /latest for a whisper participant" do
      # Participant is in TOPIC_WHISPER_PARTICIPANTS_FIELD per the outer before.
      ids = latest_topic_ids(participant)
      expect(ids.index(topic.id)).to be < ids.index(public_topic.id)
    end

    it "demotes the whispered topic below the public topic for a non-audience viewer" do
      ids = latest_topic_ids(stranger)
      expect(ids.index(public_topic.id)).to be < ids.index(topic.id)
    end

    it "serializes audience-aware bumped_at on /latest (audience sees actual, stranger sees non-whisper)" do
      sign_in(stranger)
      get "/latest.json"
      stranger_view = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == topic.id }
      expect(Time.zone.parse(stranger_view["bumped_at"])).to be_within(2.seconds).of(
        regular_reply.reload.created_at,
      )

      sign_in(target)
      get "/latest.json"
      audience_view = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == topic.id }
      # Audience members still see the live bump (5 min ago via the outer before).
      expect(Time.zone.parse(audience_view["bumped_at"])).to be_within(2.seconds).of(
        topic.reload.bumped_at,
      )
    end

    it "skips the timestamp cast when the non_whisper_bumped_at value is malformed" do
      # The custom field is normally written by on(:post_created) as an
      # iso8601 string, but a corrupted, hand-edited, or legacy value
      # shouldn't blow up /latest. The modifier's regex guard
      # `~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'` makes the CASE branch fall
      # through to topics.bumped_at instead of attempting the cast.
      topic.custom_fields[DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD] = "not-a-time"
      topic.save_custom_fields(true)

      sign_in(stranger)
      get "/latest.json"
      expect(response.status).to eq(200)
    end
  end
end
