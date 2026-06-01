# frozen_string_literal: true

require "rails_helper"

# Extra edge-case coverage for the moderator-messages endpoints —
# parameter coercion, idempotency, and audit-style behaviour. Complements
# spec/requests/mod_messages_spec.rb without duplicating its examples.
RSpec.describe "Moderator messages endpoints — edge cases" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  before { SiteSetting.mod_categories_enabled = true }

  describe "PUT /discourse-mod-categories/topic/:topic_id (idempotency)" do
    it "is idempotent for setting the same footer message twice" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "Same value.",
          }
      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "Same value.",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_footer_message"]).to eq("Same value.")
    end

    it "leaves the footer message untouched when only the reply prompt changes" do
      topic.custom_fields["mod_topic_footer_message"] = "Keep me."
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            reply_prompt: "A new reply prompt.",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_footer_message"]).to eq("Keep me.")
      expect(topic.custom_fields["mod_topic_reply_prompt"]).to eq("A new reply prompt.")
    end

    it "accepts whitespace-only inputs without crashing" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "   ",
            reply_prompt: "\n\t",
          }

      expect(response.status).to eq(200)
    end
  end

  describe "approval-flag coercion" do
    it "treats 'true' (string) as true" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            require_reply_approval: "true",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_require_reply_approval"]).to eq(true)
    end

    it "treats 'false' (string) as false" do
      topic.custom_fields["mod_topic_require_reply_approval"] = true
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            require_reply_approval: "false",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_require_reply_approval"]).to eq(false)
    end
  end

  describe "trust-level cap edge cases" do
    it "treats a string-form trust-level cap as the equivalent integer" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            reply_prompt: "x",
            reply_prompt_max_tl: "2",
          }

      expect(response.parsed_body["reply_prompt_max_tl"]).to eq(2)
    end

    it "clamps an obviously-too-large new-topic trust-level cap" do
      sign_in(moderator)

      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "x",
            new_topic_prompt_max_tl: 1_000_000,
          }

      expect(response.parsed_body["new_topic_prompt_max_tl"]).to eq(4)
    end
  end

  describe "GET /discourse-mod-categories/notes-feed (ordering)" do
    fab!(:older_topic) do
      Fabricate(:topic, category: category, title: "An older thread waiting on a moderator review")
    end
    fab!(:newer_topic) do
      Fabricate(:topic, category: category, title: "A newer thread waiting on a moderator review")
    end

    before do
      older_topic.custom_fields["mod_topic_private_note"] = "Older note."
      older_topic.custom_fields["mod_topic_private_note_activity_at"] = 3.days.ago.iso8601
      older_topic.save_custom_fields(true)

      newer_topic.custom_fields["mod_topic_private_note"] = "Newer note."
      newer_topic.custom_fields["mod_topic_private_note_activity_at"] = Time.zone.now.iso8601
      newer_topic.save_custom_fields(true)
    end

    it "orders notes with the most recent activity first" do
      sign_in(moderator)

      get "/discourse-mod-categories/notes-feed.json"

      ids = response.parsed_body["notes"].map { |n| n["topic_id"] }
      newer_idx = ids.index(newer_topic.id)
      older_idx = ids.index(older_topic.id)
      expect(newer_idx).not_to be_nil
      expect(older_idx).not_to be_nil
      expect(newer_idx).to be < older_idx
    end

    it "excludes topics that have no private note" do
      sign_in(moderator)

      get "/discourse-mod-categories/notes-feed.json"

      ids = response.parsed_body["notes"].map { |n| n["topic_id"] }
      expect(ids).not_to include(topic.id)
    end
  end

  describe "private-note position normalisation" do
    %w[top bottom].each do |pos|
      it "preserves '#{pos}' as the position" do
        sign_in(moderator)

        put "/discourse-mod-categories/topic/#{topic.id}.json",
            params: {
              private_note: "n",
              private_note_position: pos,
            }

        expect(topic.reload.custom_fields["mod_topic_private_note_position"]).to eq(pos)
      end
    end

    [nil, "", "TOP", "Bottom", "side", "left"].each do |pos|
      it "falls back to bottom for unrecognised position #{pos.inspect}" do
        sign_in(moderator)

        put "/discourse-mod-categories/topic/#{topic.id}.json",
            params: {
              private_note: "n",
              private_note_position: pos,
            }

        expect(topic.reload.custom_fields["mod_topic_private_note_position"]).to eq("bottom")
      end
    end
  end

  describe "note-reply identifiers" do
    it "generates a unique id per reply" do
      sign_in(moderator)

      4.times do |i|
        post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
             params: {
               raw: "Reply #{i}.",
             }
      end

      ids = topic.reload.custom_fields["mod_topic_private_note_replies"].map { |r| r["id"] }

      expect(ids.size).to eq(4)
      expect(ids.uniq.size).to eq(4)
    end

    it "records the moderator id and created_at for each reply" do
      sign_in(moderator)

      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json", params: { raw: "Hello." }

      reply = topic.reload.custom_fields["mod_topic_private_note_replies"].last
      expect(reply["user_id"]).to eq(moderator.id)
      expect(reply["created_at"]).to be_present
    end
  end
end
