# frozen_string_literal: true

require "rails_helper"

# Verifies the moderator-message custom fields are serialized so the
# frontend can read them: topic fields on the topic view, the category
# prompt on serialized categories.
RSpec.describe "Moderator messages serialization" do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:moderator)
  fab!(:user)

  before { SiteSetting.mod_categories_enabled = true }

  it "exposes the topic footer message, reply prompt and pinned post id" do
    topic.custom_fields["mod_topic_footer_message"] = "Footer here"
    topic.custom_fields["mod_topic_reply_prompt"] = "Reply prompt here"
    topic.custom_fields["mod_topic_pinned_post_id"] = post.id
    topic.save_custom_fields(true)

    get "/t/#{topic.id}.json"

    expect(response.status).to eq(200)
    json = response.parsed_body
    expect(json["mod_topic_footer_message"]).to eq("Footer here")
    expect(json["mod_topic_reply_prompt"]).to eq("Reply prompt here")
    expect(json["mod_topic_pinned_post_id"]).to eq(post.id)
  end

  it "leaves the topic fields nil when nothing has been set" do
    get "/t/#{topic.id}.json"

    expect(response.status).to eq(200)
    json = response.parsed_body
    expect(json["mod_topic_footer_message"]).to be_nil
    expect(json["mod_topic_reply_prompt"]).to be_nil
    expect(json["mod_topic_pinned_post_id"]).to be_nil
  end

  it "exposes the category new-topic prompt in the categories list" do
    category.custom_fields["mod_category_new_topic_prompt"] = "Category prompt"
    category.save_custom_fields(true)

    get "/categories.json"

    expect(response.status).to eq(200)
    categories = response.parsed_body["category_list"]["categories"]
    target = categories.find { |c| c["id"] == category.id }
    expect(target["mod_category_new_topic_prompt"]).to eq("Category prompt")
  end

  context "with a private moderator note set" do
    before do
      topic.custom_fields["mod_topic_private_note"] = "Staff eyes only"
      topic.custom_fields["mod_topic_private_note_position"] = "top"
      topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
      topic.save_custom_fields(true)
    end

    it "includes the note author (username and avatar) for staff" do
      sign_in(moderator)

      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      author = response.parsed_body["mod_topic_private_note_author"]
      expect(author).to be_present
      expect(author["username"]).to eq(moderator.username)
      expect(author["avatar_template"]).to be_present
    end

    it "hides the note author from regular users" do
      sign_in(user)

      get "/t/#{topic.id}.json"

      expect(response.parsed_body).not_to have_key(
        "mod_topic_private_note_author",
      )
    end

    it "exposes the private note to staff" do
      sign_in(moderator)

      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["mod_topic_private_note"]).to eq("Staff eyes only")
      expect(json["mod_topic_private_note_position"]).to eq("top")
    end

    it "hides the private note from regular users" do
      sign_in(user)

      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json).not_to have_key("mod_topic_private_note")
      expect(json).not_to have_key("mod_topic_private_note_position")
    end

    it "hides the private note from anonymous users" do
      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json).not_to have_key("mod_topic_private_note")
    end
  end

  describe "moderator-note unread count" do
    it "exposes an unread count to staff via the current user" do
      topic.custom_fields["mod_topic_private_note_activity_at"] = Time
        .zone
        .now
        .iso8601
      topic.save_custom_fields(true)
      sign_in(moderator)

      get "/session/current.json"

      expect(response.status).to eq(200)
      count =
        response.parsed_body["current_user"]["mod_note_unread_count"]
      expect(count).to be >= 1
    end

    it "reports zero once the staff member has seen the feed" do
      topic.custom_fields["mod_topic_private_note_activity_at"] =
        2.days.ago.iso8601
      topic.save_custom_fields(true)
      moderator.custom_fields["mod_notes_seen_at"] = Time.zone.now.iso8601
      moderator.save_custom_fields(true)
      sign_in(moderator)

      get "/session/current.json"

      expect(
        response.parsed_body["current_user"]["mod_note_unread_count"],
      ).to eq(0)
    end
  end
end
