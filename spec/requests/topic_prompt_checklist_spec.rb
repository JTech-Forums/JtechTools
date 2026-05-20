# frozen_string_literal: true

require "rails_helper"

# Covers the per-topic prompt checklist: staff CRUD the checklist on the
# topic admin's "Prompt Checklist" entry, and the owed endpoint factors
# the per-topic checklist in when a topic_id is supplied. Acceptance is
# recorded per-topic-per-user with a version, and a staff edit bumps the
# version so previously-accepted users are re-prompted.
RSpec.describe "Per-topic prompt checklist" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:other_topic) { Fabricate(:topic, category: category) }

  let(:topic_field) { DiscourseModCategories::TOPIC_PROMPT_CHECKLIST_FIELD }
  let(:user_field) { DiscourseModCategories::USER_TOPIC_CHECKLIST_FIELD }

  before { SiteSetting.mod_categories_enabled = true }

  def get_checklist(t)
    raw = t.reload.custom_fields[topic_field]
    raw.is_a?(Hash) ? raw : nil
  end

  describe "GET /topic/:topic_id/prompt-checklist" do
    it "returns the current checklist to a moderator" do
      topic.custom_fields[topic_field] = {
        "version" => 2,
        "items" => [{ "label" => "Read the rules", "url" => "" }],
        "button_label" => "Agree",
        "updated_at" => "2026-01-01T00:00:00Z",
      }
      topic.save_custom_fields(true)
      sign_in(moderator)

      get "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["version"]).to eq(2)
      expect(response.parsed_body["items"].first["label"]).to eq("Read the rules")
      expect(response.parsed_body["button_label"]).to eq("Agree")
    end

    it "returns an empty checklist when none is set" do
      sign_in(admin)
      get "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["version"]).to eq(0)
      expect(response.parsed_body["items"]).to eq([])
    end

    it "forbids a regular user" do
      sign_in(user)
      get "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json"
      expect(response.status).to eq(403)
    end

    it "404s for an unknown topic" do
      sign_in(moderator)
      get "/discourse-mod-categories/topic/999999/prompt-checklist.json"
      expect(response.status).to eq(404)
    end
  end

  describe "PUT /topic/:topic_id/prompt-checklist" do
    it "lets a moderator save the checklist and bumps the version each save" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json",
          params: {
            items: [
              { label: "Read the topic rules", url: "https://example.com" },
              { label: "Be kind", url: "" },
            ],
            button_label: "I understand",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["version"]).to eq(1)
      expect(response.parsed_body["items"].size).to eq(2)
      expect(response.parsed_body["button_label"]).to eq("I understand")
      expect(response.parsed_body["updated_at"]).to be_present

      first_at = response.parsed_body["updated_at"]

      put "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json",
          params: { items: [{ label: "One", url: "" }] }
      expect(response.parsed_body["version"]).to eq(2)
      expect(response.parsed_body["updated_at"]).to be_present
      expect(response.parsed_body["updated_at"] >= first_at).to eq(true)
    end

    it "drops rows whose label is blank" do
      sign_in(moderator)
      put "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json",
          params: {
            items: [
              { label: "Keep me", url: "" },
              { label: "   ", url: "https://example.com" },
              { label: "", url: "" },
            ],
          }
      expect(response.parsed_body["items"].map { |i| i["label"] }).to eq(
        ["Keep me"],
      )
    end

    it "accepts the index-keyed-hash shape a browser form-encodes" do
      sign_in(moderator)
      put "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json",
          params: {
            items: {
              "0" => { label: "First", url: "" },
              "1" => { label: "Second", url: "" },
            },
          }
      expect(response.parsed_body["items"].map { |i| i["label"] }).to eq(
        %w[First Second],
      )
    end

    it "forbids a regular user" do
      sign_in(user)
      put "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json",
          params: { items: [{ label: "x", url: "" }] }
      expect(response.status).to eq(403)
      expect(get_checklist(topic)).to be_nil
    end
  end

  describe "DELETE /topic/:topic_id/prompt-checklist" do
    it "clears the checklist" do
      topic.custom_fields[topic_field] = {
        "version" => 1,
        "items" => [{ "label" => "x", "url" => "" }],
      }
      topic.save_custom_fields(true)
      sign_in(moderator)

      delete "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["version"]).to eq(0)
      expect(response.parsed_body["items"]).to eq([])
      expect(get_checklist(topic)).to be_nil
    end

    it "forbids a regular user" do
      sign_in(user)
      delete "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json"
      expect(response.status).to eq(403)
    end
  end

  describe "GET /checklist/owed?topic_id=..." do
    before do
      topic.custom_fields[topic_field] = {
        "version" => 1,
        "items" => [{ "label" => "Confirm this topic's rule", "url" => "" }],
        "button_label" => "Agree",
        "updated_at" => "2026-01-01T00:00:00Z",
      }
      topic.save_custom_fields(true)
    end

    it "returns the per-topic checklist for a user who has not accepted" do
      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"

      expect(response.status).to eq(200)
      checklist = response.parsed_body["checklist"]
      expect(checklist).to be_present
      expect(checklist["kind"]).to eq("topic")
      expect(checklist["id"]).to eq(topic.id)
      expect(checklist["version"]).to eq(1)
      expect(checklist["items"].first["label"]).to eq(
        "Confirm this topic's rule",
      )
    end

    it "returns null after the user accepts the current version" do
      user.custom_fields[user_field] = { topic.id.to_s => 1 }
      user.save_custom_fields(true)
      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      expect(response.parsed_body["checklist"]).to be_nil
    end

    it "returns the new payload after a version bump" do
      user.custom_fields[user_field] = { topic.id.to_s => 1 }
      user.save_custom_fields(true)
      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      expect(response.parsed_body["checklist"]).to be_nil

      # Staff bump.
      topic.custom_fields[topic_field] = {
        "version" => 2,
        "items" => [{ "label" => "Updated rule", "url" => "" }],
      }
      topic.save_custom_fields(true)

      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      expect(response.parsed_body["checklist"]["version"]).to eq(2)
    end

    it "applies to staff too" do
      sign_in(moderator)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      checklist = response.parsed_body["checklist"]
      expect(checklist).to be_present
      expect(checklist["kind"]).to eq("topic")
    end

    it "ignores per-topic checklist when topic_id is absent" do
      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json"
      expect(response.parsed_body["checklist"]).to be_nil
    end

    it "ignores the checklist for OTHER topics" do
      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{other_topic.id}"
      expect(response.parsed_body["checklist"]).to be_nil
    end

    it "prefers a targeted checklist over the per-topic one" do
      PluginStore.set(
        DiscourseModCategories::CHECKLIST_STORE_NAMESPACE,
        DiscourseModCategories::TARGETED_CHECKLISTS_KEY,
        [
          {
            "id" => "tgt1",
            "name" => "Picked",
            "user_ids" => [user.id],
            "items" => [{ "label" => "Targeted item", "url" => "" }],
            "version" => 1,
            "button_label" => "",
          },
        ],
      )

      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      checklist = response.parsed_body["checklist"]
      expect(checklist["kind"]).to eq("targeted")
      expect(checklist["id"]).to eq("tgt1")
    end

    it "prefers the per-topic checklist over the global one" do
      PluginStore.set(
        DiscourseModCategories::CHECKLIST_STORE_NAMESPACE,
        DiscourseModCategories::CHECKLIST_STORE_KEY,
        {
          "version" => 1,
          "items" => [{ "label" => "Global", "url" => "" }],
        },
      )

      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      checklist = response.parsed_body["checklist"]
      expect(checklist["kind"]).to eq("topic")
    end
  end

  describe "POST /checklist/accept with kind 'topic'" do
    before do
      topic.custom_fields[topic_field] = {
        "version" => 2,
        "items" => [{ "label" => "x", "url" => "" }],
      }
      topic.save_custom_fields(true)
    end

    it "records the accepted version per-topic-per-user" do
      sign_in(user)
      post "/discourse-mod-categories/checklist/accept.json",
           params: { kind: "topic", id: topic.id, version: 2 }

      expect(response.status).to eq(200)
      map = user.reload.custom_fields[user_field]
      expect(map[topic.id.to_s]).to eq(2)
      # Other stores untouched.
      expect(
        user.custom_fields[
          DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD
        ],
      ).to be_nil
    end

    it "clamps the accepted version to the published version" do
      sign_in(user)
      post "/discourse-mod-categories/checklist/accept.json",
           params: { kind: "topic", id: topic.id, version: 99 }
      expect(user.reload.custom_fields[user_field][topic.id.to_s]).to eq(2)
    end

    it "404s when the topic has no checklist" do
      sign_in(user)
      post "/discourse-mod-categories/checklist/accept.json",
           params: { kind: "topic", id: other_topic.id, version: 1 }
      expect(response.status).to eq(404)
    end
  end

  describe "topic_view serializer" do
    it "exposes the per-topic checklist on the topic" do
      topic.custom_fields[topic_field] = {
        "version" => 1,
        "items" => [{ "label" => "x", "url" => "" }],
        "button_label" => "OK",
        "updated_at" => "2026-01-01T00:00:00Z",
      }
      topic.save_custom_fields(true)

      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.status).to eq(200)
      checklist = response.parsed_body["mod_topic_prompt_checklist"]
      expect(checklist).to be_present
      expect(checklist["version"]).to eq(1)
      expect(checklist["items"].first["label"]).to eq("x")
      # New fields default sensibly when the topic predates them.
      expect(checklist["mode"]).to eq("checklist")
      expect(checklist["frequency"]).to eq("once")
      expect(checklist["max_tl"]).to eq(4)
    end

    it "exposes a statement-mode checklist with its statement text" do
      topic.custom_fields[topic_field] = {
        "version" => 3,
        "mode" => "statement",
        "statement" => "Please confirm you have read the rules.",
        "items" => [],
        "frequency" => "every_reply",
        "max_tl" => 2,
        "button_label" => "I confirm",
        "updated_at" => "2026-01-01T00:00:00Z",
      }
      topic.save_custom_fields(true)

      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}.json"
      checklist = response.parsed_body["mod_topic_prompt_checklist"]
      expect(checklist).to be_present
      expect(checklist["mode"]).to eq("statement")
      expect(checklist["statement"]).to eq(
        "Please confirm you have read the rules.",
      )
      expect(checklist["frequency"]).to eq("every_reply")
      expect(checklist["max_tl"]).to eq(2)
    end

    it "exposes null when no checklist is set" do
      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}.json"
      expect(response.parsed_body["mod_topic_prompt_checklist"]).to be_nil
    end
  end

  describe "statement mode" do
    it "stores mode/statement/frequency/max_tl on save and bumps the version" do
      sign_in(moderator)
      put "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json",
          params: {
            mode: "statement",
            statement: "Read the rules then post.",
            frequency: "every_reply",
            max_tl: 1,
            button_label: "I agree",
          }
      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["mode"]).to eq("statement")
      expect(body["statement"]).to eq("Read the rules then post.")
      expect(body["frequency"]).to eq("every_reply")
      expect(body["max_tl"]).to eq(1)
      expect(body["version"]).to eq(1)

      stored = topic.reload.custom_fields[topic_field]
      expect(stored["mode"]).to eq("statement")
      expect(stored["statement"]).to eq("Read the rules then post.")
      expect(stored["frequency"]).to eq("every_reply")
      expect(stored["max_tl"]).to eq(1)
    end

    it "returns the statement payload on the owed endpoint with no checkboxes" do
      topic.custom_fields[topic_field] = {
        "version" => 1,
        "mode" => "statement",
        "statement" => "Confirm you have read.",
        "items" => [],
        "frequency" => "once",
        "max_tl" => 4,
        "button_label" => "OK",
      }
      topic.save_custom_fields(true)

      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      checklist = response.parsed_body["checklist"]
      expect(checklist).to be_present
      expect(checklist["kind"]).to eq("topic")
      expect(checklist["mode"]).to eq("statement")
      expect(checklist["statement"]).to eq("Confirm you have read.")
    end

    it "treats a blank statement (statement mode) as inactive" do
      topic.custom_fields[topic_field] = {
        "version" => 1,
        "mode" => "statement",
        "statement" => "   ",
        "items" => [],
        "frequency" => "once",
        "max_tl" => 4,
      }
      topic.save_custom_fields(true)

      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      expect(response.parsed_body["checklist"]).to be_nil
    end

    it "owed_checklist_for returns the full statement payload with no items" do
      topic.custom_fields[topic_field] = {
        "version" => 5,
        "mode" => "statement",
        "statement" => "Please confirm you have read.",
        "items" => [],
        "frequency" => "once",
        "max_tl" => 4,
        "button_label" => "I confirm",
        "updated_at" => "2026-02-02T00:00:00Z",
      }
      topic.save_custom_fields(true)

      payload =
        DiscourseModCategories.owed_checklist_for(user, topic_id: topic.id)
      expect(payload).to be_present
      expect(payload[:kind]).to eq("topic")
      expect(payload[:id]).to eq(topic.id)
      expect(payload[:version]).to eq(5)
      expect(payload[:mode]).to eq("statement")
      expect(payload[:statement]).to eq("Please confirm you have read.")
      expect(payload[:items]).to eq([])
      expect(payload[:button_label]).to eq("I confirm")
      expect(payload[:updated_at]).to eq("2026-02-02T00:00:00Z")
    end
  end

  describe "frequency: every_reply" do
    it "always returns the per-topic checklist, even after acceptance" do
      topic.custom_fields[topic_field] = {
        "version" => 1,
        "mode" => "checklist",
        "items" => [{ "label" => "x", "url" => "" }],
        "frequency" => "every_reply",
        "max_tl" => 4,
      }
      topic.save_custom_fields(true)
      user.custom_fields[user_field] = { topic.id.to_s => 1 }
      user.save_custom_fields(true)

      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      checklist = response.parsed_body["checklist"]
      expect(checklist).to be_present
      expect(checklist["frequency"]).to eq("every_reply")
    end
  end

  describe "max_tl cap" do
    before do
      topic.custom_fields[topic_field] = {
        "version" => 1,
        "mode" => "checklist",
        "items" => [{ "label" => "x", "url" => "" }],
        "frequency" => "once",
        "max_tl" => 1,
      }
      topic.save_custom_fields(true)
    end

    it "filters out a TL2 non-staff user" do
      sign_in(user)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      expect(response.parsed_body["checklist"]).to be_nil
    end

    it "still shows the checklist to staff regardless of cap" do
      sign_in(moderator)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      checklist = response.parsed_body["checklist"]
      expect(checklist).to be_present
    end

    it "still shows the checklist to a TL0 user when the cap is TL1" do
      tl0 = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(tl0)
      get "/discourse-mod-categories/checklist/owed.json?topic_id=#{topic.id}"
      expect(response.parsed_body["checklist"]).to be_present
    end
  end

  describe "legacy reply-prompt migration" do
    it "pre-fills the editor seed in statement mode from the legacy fields" do
      topic.custom_fields[
        DiscourseModCategories::TOPIC_REPLY_PROMPT_FIELD
      ] = "Legacy reply prompt text."
      topic.custom_fields[
        DiscourseModCategories::TOPIC_REPLY_PROMPT_TL_FIELD
      ] = 1
      topic.save_custom_fields(true)
      sign_in(moderator)

      get "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json"
      body = response.parsed_body
      expect(body["mode"]).to eq("statement")
      expect(body["statement"]).to eq("Legacy reply prompt text.")
      expect(body["max_tl"]).to eq(1)
      expect(body["from_legacy"]).to eq(true)
    end

    it "saving the editor migrates: legacy fields cleared, new config wins" do
      topic.custom_fields[
        DiscourseModCategories::TOPIC_REPLY_PROMPT_FIELD
      ] = "Legacy reply prompt text."
      topic.custom_fields[
        DiscourseModCategories::TOPIC_REPLY_PROMPT_TL_FIELD
      ] = 1
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json",
          params: {
            mode: "statement",
            statement: "Legacy reply prompt text.",
            max_tl: 1,
          }

      expect(response.status).to eq(200)
      topic.reload
      stored = topic.custom_fields[topic_field]
      expect(stored["mode"]).to eq("statement")
      expect(stored["statement"]).to eq("Legacy reply prompt text.")
      expect(
        topic.custom_fields[
          DiscourseModCategories::TOPIC_REPLY_PROMPT_FIELD
        ],
      ).to be_blank
      expect(
        topic.custom_fields[
          DiscourseModCategories::TOPIC_REPLY_PROMPT_TL_FIELD
        ],
      ).to be_blank
    end

    it "does not flag from_legacy when the new config already exists" do
      topic.custom_fields[topic_field] = {
        "version" => 1,
        "mode" => "checklist",
        "items" => [{ "label" => "x", "url" => "" }],
        "frequency" => "once",
        "max_tl" => 4,
      }
      topic.custom_fields[
        DiscourseModCategories::TOPIC_REPLY_PROMPT_FIELD
      ] = "Legacy still around."
      topic.save_custom_fields(true)
      sign_in(moderator)

      get "/discourse-mod-categories/topic/#{topic.id}/prompt-checklist.json"
      expect(response.parsed_body["from_legacy"]).to eq(false)
      expect(response.parsed_body["mode"]).to eq("checklist")
    end
  end
end
