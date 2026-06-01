# frozen_string_literal: true

require "rails_helper"

# Verifies the POST /discourse-mod-categories/topic/:topic_id/note-view
# endpoint: records the current staff user as a viewer of the mod-note
# panel, idempotently (re-views update viewed_at on the existing entry
# rather than appending a duplicate), and gates non-staff out.
RSpec.describe "Record mod-note view" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_moderator, :moderator)
  fab!(:user)
  fab!(:topic)

  before do
    SiteSetting.mod_categories_enabled = true
    topic.custom_fields[DiscourseModCategories::TOPIC_PRIVATE_NOTE_FIELD] = "Triage in progress."
    topic.save_custom_fields(true)
  end

  def viewers
    Array(topic.reload.custom_fields[DiscourseModCategories::TOPIC_NOTE_VIEWERS_FIELD])
  end

  it "appends the current user when they have not viewed yet" do
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{topic.id}/note-view.json"

    expect(response.status).to eq(200)
    expect(viewers.map { |v| v["user_id"] }).to contain_exactly(admin.id)
    expect(viewers.first["username"]).to eq(admin.username)
    expect(viewers.first["viewed_at"]).to be_present
  end

  it "updates viewed_at on re-view without duplicating the entry" do
    # `travel` (ActiveSupport::Testing::TimeHelpers) isn't auto-included
    # by Discourse's rails_helper, so we use freeze_time which IS
    # available there. Two POSTs at deterministically-different times
    # let us assert both the no-duplicate semantic AND the timestamp
    # progression.
    sign_in(admin)

    freeze_time(30.minutes.ago) do
      post "/discourse-mod-categories/topic/#{topic.id}/note-view.json"
    end
    first_time = viewers.first["viewed_at"]

    freeze_time(Time.zone.now) { post "/discourse-mod-categories/topic/#{topic.id}/note-view.json" }

    expect(viewers.size).to eq(1)
    expect(viewers.first["user_id"]).to eq(admin.id)
    expect(Time.zone.parse(viewers.first["viewed_at"])).to be > Time.zone.parse(first_time)
  end

  it "keeps separate entries per viewer" do
    sign_in(admin)
    post "/discourse-mod-categories/topic/#{topic.id}/note-view.json"

    sign_in(other_moderator)
    post "/discourse-mod-categories/topic/#{topic.id}/note-view.json"

    expect(viewers.map { |v| v["user_id"] }).to contain_exactly(admin.id, other_moderator.id)
  end

  it "returns the viewers array in the response" do
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{topic.id}/note-view.json"

    expect(response.parsed_body["viewers"]).to be_an(Array)
    expect(response.parsed_body["viewers"].first["username"]).to eq(admin.username)
    expect(response.parsed_body["viewers"].first["user_id"]).to eq(admin.id)
  end

  it "404s when the topic has no mod-note set" do
    no_note_topic = Fabricate(:topic)
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{no_note_topic.id}/note-view.json"

    expect(response.status).to eq(404)
  end

  it "forbids non-staff users from recording a view" do
    sign_in(user)

    post "/discourse-mod-categories/topic/#{topic.id}/note-view.json"

    expect(response.status).to eq(403)
    expect(viewers).to be_empty
  end

  it "404s for a non-existent topic" do
    sign_in(admin)
    post "/discourse-mod-categories/topic/9999999/note-view.json"
    expect(response.status).to eq(404)
  end
end
