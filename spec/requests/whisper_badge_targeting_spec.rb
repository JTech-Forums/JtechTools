# frozen_string_literal: true

require "rails_helper"

# Verifies badge-target whisper visibility:
# * A user holding a target badge sees the whisper (Guardian + topic stream).
# * A user without the badge does not.
# * Granting the badge later restores visibility (lazy membership).
RSpec.describe "Whisper badge targeting" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:badge) { Fabricate(:badge, name: "WhisperBadge") }
  fab!(:badge_holder, :user)
  fab!(:stranger, :user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: author) }
  fab!(:whisper_post) { Fabricate(:post, topic: topic, user: moderator) }

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:groups_field) { DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD }
  let(:badges_field) { DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    Group.refresh_automatic_groups!

    BadgeGranter.grant(badge, badge_holder)

    whisper_post.custom_fields[targets_field] = []
    whisper_post.custom_fields[groups_field] = []
    whisper_post.custom_fields[badges_field] = [badge.id]
    whisper_post.save_custom_fields(true)
  end

  def stream_post_ids
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    response.parsed_body["post_stream"]["posts"].map { |p| p["id"] }
  end

  describe "Guardian" do
    it "permits a badge holder to see the whisper" do
      expect(Guardian.new(badge_holder).can_see_post?(whisper_post.reload)).to eq(true)
    end

    it "denies a non-holder" do
      expect(Guardian.new(stranger).can_see_post?(whisper_post.reload)).to eq(false)
    end

    it "permits staff regardless of badge membership" do
      expect(Guardian.new(admin).can_see_post?(whisper_post.reload)).to eq(true)
      expect(Guardian.new(moderator).can_see_post?(whisper_post.reload)).to eq(true)
    end
  end

  describe "WhisperQueryFilter" do
    def filter(user)
      DiscourseModCategories::WhisperQueryFilter.apply(
        Post.where(id: whisper_post.id),
        user,
      ).exists?
    end

    it "shows the whisper to a badge holder" do
      expect(filter(badge_holder)).to eq(true)
    end

    it "hides the whisper from a non-holder" do
      expect(filter(stranger)).to eq(false)
    end

    it "shows the whisper to staff" do
      expect(filter(admin)).to eq(true)
    end

    it "matches Guardian decision across personas" do
      [nil, author, badge_holder, stranger, admin, moderator].each do |user|
        guardian_visible = Guardian.new(user).can_see_post?(whisper_post.reload)
        sql_visible = filter(user)
        expect(sql_visible).to eq(guardian_visible),
        "QueryFilter (#{sql_visible}) disagrees with Guardian " \
          "(#{guardian_visible}) for user #{user&.username || "anonymous"}"
      end
    end
  end

  describe "topic stream rendering" do
    it "includes the whisper for a badge holder" do
      sign_in(badge_holder)
      expect(stream_post_ids).to include(whisper_post.id)
    end

    it "excludes the whisper from a non-holder" do
      sign_in(stranger)
      expect(stream_post_ids).not_to include(whisper_post.id)
    end

    it "serializes the target badge on the post" do
      sign_in(badge_holder)
      get "/t/#{topic.id}.json"
      post_json =
        response.parsed_body["post_stream"]["posts"].find { |p| p["id"] == whisper_post.id }
      expect(post_json["mod_whisper_target_badge_ids"]).to eq([badge.id])
      expect(post_json["mod_whisper_target_badges"]).to eq(
        [{ "id" => badge.id, "name" => badge.display_name }],
      )
      expect(post_json["mod_whisper_is_staff_only"]).to eq(false)
    end
  end

  describe "lazy membership" do
    it "grants visibility when the badge is granted later" do
      expect(Guardian.new(stranger).can_see_post?(whisper_post.reload)).to eq(false)
      BadgeGranter.grant(badge, stranger)
      expect(Guardian.new(stranger).can_see_post?(whisper_post.reload)).to eq(true)
    end

    it "removes visibility when the badge is revoked later" do
      expect(Guardian.new(badge_holder).can_see_post?(whisper_post.reload)).to eq(true)
      UserBadge.where(user_id: badge_holder.id, badge_id: badge.id).destroy_all
      expect(Guardian.new(badge_holder).can_see_post?(whisper_post.reload)).to eq(false)
    end
  end
end
