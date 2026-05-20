# frozen_string_literal: true

require "rails_helper"

# Exercises POST /discourse-mod-categories/topic/:topic_id/whisper-participant:
# staff add a user to a topic's whisper conversation, non-staff are forbidden,
# adding the same user twice does not duplicate, and an added user can then
# see an existing whisper post in that topic.
RSpec.describe "Whisper add participant" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:newcomer, :user)
  fab!(:stranger, :user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: author) }
  fab!(:whisper_post) { Fabricate(:post, topic: topic, user: moderator) }

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:participants_field) do
    DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD
  end
  let(:url) do
    "/discourse-mod-categories/topic/#{topic.id}/whisper-participant.json"
  end

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true

    whisper_post.custom_fields[targets_field] = []
    whisper_post.save_custom_fields(true)
  end

  def participant_ids
    Array(topic.reload.custom_fields[participants_field]).map(&:to_i)
  end

  it "lets a moderator add a user to the whisper conversation" do
    sign_in(moderator)

    post url, params: { username: newcomer.username }

    expect(response.status).to eq(200)
    expect(response.parsed_body["participant_ids"]).to include(newcomer.id)
    expect(participant_ids).to include(newcomer.id)
  end

  it "lets an admin add a user by user_id" do
    sign_in(admin)

    post url, params: { user_id: newcomer.id }

    expect(response.status).to eq(200)
    expect(participant_ids).to include(newcomer.id)
  end

  it "forbids a regular user" do
    sign_in(stranger)

    post url, params: { username: newcomer.username }

    expect(response.status).to eq(403)
    expect(participant_ids).not_to include(newcomer.id)
  end

  it "forbids an anonymous user" do
    post url, params: { username: newcomer.username }

    expect(response.status).to eq(403)
  end

  it "does not duplicate when the same user is added twice" do
    sign_in(moderator)

    post url, params: { username: newcomer.username }
    expect(response.status).to eq(200)
    post url, params: { username: newcomer.username }
    expect(response.status).to eq(200)

    expect(participant_ids.count(newcomer.id)).to eq(1)
  end

  it "404s for an unknown username" do
    sign_in(moderator)

    post url, params: { username: "does-not-exist" }

    expect(response.status).to eq(400)
  end

  it "404s when whispers are disabled" do
    SiteSetting.mod_whisper_enabled = false
    sign_in(moderator)

    post url, params: { username: newcomer.username }

    expect(response.status).to eq(404)
  end

  it "lets the added user see an existing whisper post in the topic" do
    expect(Guardian.new(newcomer).can_see_post?(whisper_post)).to eq(false)

    sign_in(moderator)
    post url, params: { username: newcomer.username }
    expect(response.status).to eq(200)

    expect(
      Guardian.new(newcomer).can_see_post?(whisper_post.reload),
    ).to eq(true)

    sign_in(newcomer)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    ids = response.parsed_body["post_stream"]["posts"].map { |p| p["id"] }
    expect(ids).to include(whisper_post.id)
  end

  it "notifies the added user" do
    sign_in(moderator)

    expect {
      post url, params: { username: newcomer.username }
    }.to change {
      Notification.where(user_id: newcomer.id).count
    }.by(1)
  end
end
