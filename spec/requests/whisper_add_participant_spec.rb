# frozen_string_literal: true

require "rails_helper"

# Exercises POST /discourse-mod-categories/topic/:topic_id/whisper-participant:
# staff add a user to ONE whisper's audience (its explicit targets). The
# added user sees that whisper — and never the other whispers in the topic.
# Non-staff are forbidden and adding the same user twice does not duplicate.
RSpec.describe "Whisper add participant" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:newcomer, :user)
  fab!(:stranger, :user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: author) }
  fab!(:whisper_post) { Fabricate(:post, topic: topic, user: moderator) }
  fab!(:other_whisper) { Fabricate(:post, topic: topic, user: moderator) }

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:participants_field) { DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD }
  let(:url) { "/discourse-mod-categories/topic/#{topic.id}/whisper-participant.json" }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true

    [whisper_post, other_whisper].each do |p|
      p.custom_fields[targets_field] = []
      p.save_custom_fields(true)
    end
  end

  def participant_ids
    Array(topic.reload.custom_fields[participants_field]).map(&:to_i)
  end

  def target_ids(post)
    Array(post.reload.custom_fields[targets_field]).map(&:to_i)
  end

  it "lets a moderator add a user to a whisper" do
    sign_in(moderator)

    post url, params: { username: newcomer.username, post_id: whisper_post.id }

    expect(response.status).to eq(200)
    expect(response.parsed_body["mod_whisper_target_user_ids"]).to include(newcomer.id)
    expect(target_ids(whisper_post)).to include(newcomer.id)
    # Recorded as a participant only so they may whisper back to staff.
    expect(participant_ids).to include(newcomer.id)
  end

  it "lets an admin add a user by user_id" do
    sign_in(admin)

    post url, params: { user_id: newcomer.id, post_id: whisper_post.id }

    expect(response.status).to eq(200)
    expect(target_ids(whisper_post)).to include(newcomer.id)
  end

  it "requires a whisper post in the topic" do
    sign_in(moderator)

    post url, params: { username: newcomer.username }
    expect(response.status).to eq(400)

    post url, params: { username: newcomer.username, post_id: op.id }
    expect(response.status).to eq(400)

    elsewhere = Fabricate(:post)
    elsewhere.custom_fields[targets_field] = []
    elsewhere.save_custom_fields(true)
    post url, params: { username: newcomer.username, post_id: elsewhere.id }
    expect(response.status).to eq(400)
  end

  it "forbids a regular user" do
    sign_in(stranger)

    post url, params: { username: newcomer.username, post_id: whisper_post.id }

    expect(response.status).to eq(403)
    expect(target_ids(whisper_post)).not_to include(newcomer.id)
  end

  it "forbids an anonymous user" do
    post url, params: { username: newcomer.username, post_id: whisper_post.id }

    expect(response.status).to eq(403)
  end

  it "does not duplicate when the same user is added twice" do
    sign_in(moderator)

    2.times do
      post url, params: { username: newcomer.username, post_id: whisper_post.id }
      expect(response.status).to eq(200)
    end

    expect(target_ids(whisper_post).count(newcomer.id)).to eq(1)
    expect(participant_ids.count(newcomer.id)).to eq(1)
  end

  it "400s for an unknown username" do
    sign_in(moderator)

    post url, params: { username: "does-not-exist", post_id: whisper_post.id }

    expect(response.status).to eq(400)
  end

  it "404s when whispers are disabled" do
    SiteSetting.mod_whisper_enabled = false
    sign_in(moderator)

    post url, params: { username: newcomer.username, post_id: whisper_post.id }

    expect(response.status).to eq(404)
  end

  it "lets the added user see that whisper — and no other whisper in the topic" do
    expect(Guardian.new(newcomer).can_see_post?(whisper_post)).to eq(false)

    sign_in(moderator)
    post url, params: { username: newcomer.username, post_id: whisper_post.id }
    expect(response.status).to eq(200)

    expect(Guardian.new(newcomer).can_see_post?(whisper_post.reload)).to eq(true)
    expect(Guardian.new(newcomer).can_see_post?(other_whisper.reload)).to eq(false)

    sign_in(newcomer)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    ids = response.parsed_body["post_stream"]["posts"].map { |p| p["id"] }
    expect(ids).to include(whisper_post.id)
    expect(ids).not_to include(other_whisper.id)
  end

  it "notifies the added user" do
    sign_in(moderator)

    expect {
      post url, params: { username: newcomer.username, post_id: whisper_post.id }
    }.to change { Notification.where(user_id: newcomer.id).count }.by(1)
  end
end
