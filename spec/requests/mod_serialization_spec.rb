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

  it "exposes the pinned post's render payload alongside the id" do
    topic.custom_fields["mod_topic_pinned_post_id"] = post.id
    topic.save_custom_fields(true)

    get "/t/#{topic.id}.json"

    expect(response.status).to eq(200)
    payload = response.parsed_body["mod_topic_pinned_post"]
    expect(payload).to be_present
    expect(payload["id"]).to eq(post.id)
    expect(payload["post_number"]).to eq(post.post_number)
    expect(payload["cooked"]).to eq(post.cooked)
    expect(payload["username"]).to eq(post.user.username)
    expect(payload["avatar_template"]).to eq(post.user.avatar_template)
  end

  it "returns a null mod_topic_pinned_post when no post is pinned" do
    get "/t/#{topic.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["mod_topic_pinned_post"]).to be_nil
  end

  it "leaves the topic fields nil when nothing has been set" do
    get "/t/#{topic.id}.json"

    expect(response.status).to eq(200)
    json = response.parsed_body
    expect(json["mod_topic_footer_message"]).to be_nil
    expect(json["mod_topic_reply_prompt"]).to be_nil
    expect(json["mod_topic_pinned_post_id"]).to be_nil
    expect(json["mod_topic_pinned_post"]).to be_nil
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

      expect(response.parsed_body).not_to have_key("mod_topic_private_note_author")
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
    # The count is derived from unread Notification rows tagged with
    # `mod_note: true` in their data — the same rows that drive the avatar
    # bell dot — so reading a mod-note from either the bell or the shield
    # tab decrements both counts together.
    def make_mod_note_notification(user, read: false)
      ::Notification.create!(
        notification_type: ::Notification.types[:custom],
        user_id: user.id,
        read: read,
        data: { mod_note: true, topic_title: "x", display_username: "y" }.to_json,
      )
    end

    it "exposes an unread count to staff via the current user" do
      make_mod_note_notification(moderator)
      sign_in(moderator)

      get "/session/current.json"

      expect(response.status).to eq(200)
      count = response.parsed_body["current_user"]["mod_note_unread_count"]
      expect(count).to be >= 1
    end

    it "reports zero once every mod-note notification is read" do
      make_mod_note_notification(moderator, read: true)
      sign_in(moderator)

      get "/session/current.json"

      expect(response.parsed_body["current_user"]["mod_note_unread_count"]).to eq(0)
    end
  end
end
