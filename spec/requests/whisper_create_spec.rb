# frozen_string_literal: true

require "rails_helper"

# Exercises whisper post creation through POST /posts: staff targeted
# whispers, staff-only whispers, non-staff whisper-backs, and the
# non-participant gate. A whisper is created only when the explicit
# `mod_whisper` armed flag is sent — the target count never implies it.
RSpec.describe "Whisper creation" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:target, :user)
  fab!(:participant, :user)
  fab!(:stranger, :user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: author) }
  fab!(:whisper_group) { Fabricate(:group, name: "whisper_squad") }

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:groups_field) { DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD }
  let(:armed_param) { DiscourseModCategories::POST_WHISPER_ARMED_PARAM }
  let(:participants_field) { DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    # Keep low-trust-level users out of the review queue so their posts are
    # created directly.
    Group.refresh_automatic_groups!
    SiteSetting.approve_unless_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
  end

  def create_post_for(user, params)
    sign_in(user)
    post "/posts.json",
         params: {
           topic_id: topic.id,
           raw: "This is a whisper reply body long enough to be valid.",
         }.merge(params)
  end

  describe "staff-authored targeted whisper" do
    it "marks the post and records the non-staff target as a participant" do
      create_post_for(
        moderator,
        { armed_param => true, targets_field => [target.id, participant.id] },
      )
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields.key?(targets_field)).to eq(true)
      expect(created.custom_fields[targets_field].map(&:to_i)).to match_array(
        [target.id, participant.id],
      )

      topic.reload
      expect(Array(topic.custom_fields[participants_field]).map(&:to_i)).to match_array(
        [target.id, participant.id],
      )
    end

    it "notifies the chosen targets" do
      Jobs.run_immediately!
      target_baseline = Notification.where(user_id: target.id).count

      create_post_for(moderator, { armed_param => true, targets_field => [target.id] })
      expect(response.status).to eq(200)

      expect(Notification.where(user_id: target.id).count).to(be > target_baseline)
    end

    it "creates a normal post when the whisper flag is not armed" do
      create_post_for(moderator, {})
      expect(response.status).to eq(200)
      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields.key?(targets_field)).to eq(false)
    end

    # Regression: a staff member arming a whisper with NO targets selected
    # intends a staff-only whisper. The empty-array case must not be dropped.
    it "creates a staff-only whisper when armed with no targets param" do
      create_post_for(moderator, { armed_param => true })
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields.key?(targets_field)).to eq(true)
      expect(created.custom_fields[targets_field]).to eq([])
    end

    it "creates a staff-only whisper when armed with an empty targets array" do
      create_post_for(moderator, { armed_param => true, targets_field => [] })
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields.key?(targets_field)).to eq(true)
      expect(created.custom_fields[targets_field]).to eq([])
    end
  end

  describe "staff-authored group whisper" do
    it "validates and stores the submitted group ids" do
      create_post_for(moderator, { armed_param => true, groups_field => [whisper_group.id] })
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields.key?(targets_field)).to eq(true)
      expect(created.custom_fields[groups_field].map(&:to_i)).to eq([whisper_group.id])
    end

    it "drops group ids that do not map to a real group" do
      create_post_for(
        moderator,
        { armed_param => true, groups_field => [whisper_group.id, 999_999] },
      )
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields[groups_field].map(&:to_i)).to eq([whisper_group.id])
    end

    it "supports a whisper carrying both user and group targets" do
      create_post_for(
        moderator,
        { armed_param => true, targets_field => [target.id], groups_field => [whisper_group.id] },
      )
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields[targets_field].map(&:to_i)).to eq([target.id])
      expect(created.custom_fields[groups_field].map(&:to_i)).to eq([whisper_group.id])
    end
  end

  describe "non-staff whisper-back" do
    before do
      topic.custom_fields[participants_field] = [participant.id]
      topic.save_custom_fields(true)
    end

    it "forces empty (staff-only) user and group lists for a participant" do
      create_post_for(
        participant,
        { armed_param => true, targets_field => [stranger.id], groups_field => [whisper_group.id] },
      )
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields.key?(targets_field)).to eq(true)
      expect(created.custom_fields[targets_field]).to eq([])
      expect(created.custom_fields[groups_field]).to eq([])
    end

    it "notifies all staff on a whisper-back" do
      Jobs.run_immediately!
      admin_baseline = Notification.where(user_id: admin.id).count

      create_post_for(participant, { armed_param => true, targets_field => [] })
      expect(response.status).to eq(200)

      expect(Notification.where(user_id: admin.id).count).to(be > admin_baseline)
    end

    # Regression: a non-staff topic whisper participant posting a NORMAL
    # reply (no whisper armed) must produce a plain public post — whisper-ness
    # is no longer inferred from participant membership.
    it "creates a normal public post when the whisper flag is not armed" do
      create_post_for(participant, {})
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields.key?(targets_field)).to eq(false)
    end
  end

  describe "non-participant non-staff user" do
    it "creates a plain post even when the whisper flag is armed" do
      create_post_for(stranger, { armed_param => true, targets_field => [target.id] })
      expect(response.status).to eq(200)

      created = Post.find(response.parsed_body["id"])
      expect(created.custom_fields.key?(targets_field)).to eq(false)
    end
  end
end
