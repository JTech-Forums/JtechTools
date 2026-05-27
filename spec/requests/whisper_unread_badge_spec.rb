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
  end
end
