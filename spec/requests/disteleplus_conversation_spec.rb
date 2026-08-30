# frozen_string_literal: true

require "rails_helper"

# Security contract for the native conversation API: anonymous and
# unauthorized users are refused, authors and staff have the right powers,
# and pagination/read cursors behave.
RSpec.describe "Disteleplus conversation API" do
  fab!(:admin)
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:other) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:outsider) { Fabricate(:user, trust_level: TrustLevel[0]) }

  let(:base) { "/jtech-disteleplus" }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
    SiteSetting.disteleplus_bridge_bot_username = "telegram_bridge"
  end

  def create!(user, raw, **opts)
    DiscourseDisteleplus::MessageService.new(actor: user).create!(
      raw: raw,
      bridge: false,
      notify: false,
      **opts,
    )
  end

  describe "access" do
    it "refuses anonymous users" do
      get "#{base}/conversation.json"
      expect(response.status).to eq(403)
    end

    it "refuses users outside the allowed groups" do
      sign_in(outsider)
      get "#{base}/conversation.json"
      expect(response.status).to eq(403)
      post "#{base}/messages.json", params: { raw: "sneaky" }
      expect(response.status).to eq(403)
    end

    it "404s while the module is disabled" do
      SiteSetting.disteleplus_enabled = false
      sign_in(admin)
      get "#{base}/conversation.json"
      expect(response.status).to eq(404)
    end
  end

  describe "routing" do
    it "is not swallowed by the Dumbcourse catch-all and serves the Ember shell" do
      sign_in(member)
      get "#{base}/conversation.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to have_key("messages")

      get "/disteleplus"
      expect(response.status).to eq(200)
      expect(response.body).to include("data-discourse-setup")
    end
  end

  describe "GET /conversation and /messages" do
    before { sign_in(member) }

    it "returns the newest page, meta, and paginates backwards" do
      ids = 45.times.map { |i| create!(other, "m#{i}").id }
      get "#{base}/conversation.json"
      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["messages"].length).to eq(40)
      expect(body["messages"].map { |m| m["id"] }).to eq(ids.last(40))
      expect(body["meta"]).to include(
        "has_more" => true,
        "latest_message_id" => ids.last,
        "unread_count" => 45,
        "message_bus_channel" => DiscourseDisteleplus::Publisher::CHANNEL,
      )

      get "#{base}/messages.json", params: { before_id: ids[5], limit: 3 }
      page = response.parsed_body
      expect(page["messages"].map { |m| m["id"] }).to eq(ids[2..4])
      expect(page["meta"]["has_more"]).to eq(true)

      get "#{base}/messages.json", params: { before_id: ids[1] }
      expect(response.parsed_body["messages"].map { |m| m["id"] }).to eq([ids[0]])
      expect(response.parsed_body["meta"]["has_more"]).to eq(false)
    end

    it "serializes author, permissions and Telegram sender" do
      message =
        DiscourseDisteleplus::MessageService.new(actor: admin, bypass_access: true).create!(
          raw: "hi",
          source: :telegram,
          external_sender_name: "Zev",
          bridge: false,
          notify: false,
        )
      get "#{base}/conversation.json"
      json = response.parsed_body["messages"].first
      expect(json).to include(
        "id" => message.id,
        "source" => "telegram",
        "external_sender_name" => "Zev",
        "can_edit" => false,
        "can_delete" => false,
        "can_react" => true,
      )
      expect(json["user"]).to include("username" => admin.username)
    end
  end

  describe "POST /messages" do
    before { sign_in(member) }

    it "creates a message with uploads and a reply" do
      parent = create!(other, "parent")
      upload = Fabricate(:upload, user: member)
      post "#{base}/messages.json",
           params: {
             raw: "hello",
             upload_ids: [upload.id],
             reply_to_id: parent.id,
           }
      expect(response.status).to eq(201)
      json = response.parsed_body["message"]
      expect(json["cooked"]).to include("hello")
      expect(json["uploads"].first["id"]).to eq(upload.id)
      expect(json["reply_to"]["id"]).to eq(parent.id)
      expect(json["can_edit"]).to eq(true)
      expect(Jobs::DisteleplusSendToTelegram.jobs.size).to eq(1)
    end

    it "rejects empty and malformed input" do
      post "#{base}/messages.json", params: { raw: "" }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present

      post "#{base}/messages.json",
           params: {
             raw: "x",
             upload_ids: [Fabricate(:upload, user: other).id],
           }
      expect(response.status).to eq(403)
    end

    it "rate limits" do
      RateLimiter.enable
      RateLimiter.clear_all!
      30.times { post "#{base}/messages.json", params: { raw: "spam" } }
      expect(response.status).to eq(201)
      post "#{base}/messages.json", params: { raw: "spam" }
      expect(response.status).to eq(429)
    end
  end

  describe "PUT/DELETE /messages/:id" do
    let!(:message) { create!(member, "mine") }

    it "lets the author edit and delete" do
      sign_in(member)
      put "#{base}/messages/#{message.id}.json", params: { raw: "edited" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["message"]["edited_at"]).to be_present

      delete "#{base}/messages/#{message.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["message"]["deleted"]).to eq(true)
    end

    it "refuses other members but lets staff moderate" do
      sign_in(other)
      put "#{base}/messages/#{message.id}.json", params: { raw: "hijack" }
      expect(response.status).to eq(403)
      delete "#{base}/messages/#{message.id}.json"
      expect(response.status).to eq(403)

      sign_in(admin)
      delete "#{base}/messages/#{message.id}.json"
      expect(response.status).to eq(200)
    end

    it "404s unknown messages" do
      sign_in(member)
      put "#{base}/messages/0.json", params: { raw: "x" }
      expect(response.status).to eq(404)
    end
  end

  describe "reactions" do
    let!(:message) { create!(other, "react") }

    it "adds and removes the current user's reaction" do
      sign_in(member)
      put "#{base}/messages/#{message.id}/reactions/fire.json"
      expect(response.status).to eq(200)
      reaction = response.parsed_body["message"]["reactions"].first
      expect(reaction).to include("emoji" => "fire", "count" => 1, "reacted" => true)

      delete "#{base}/messages/#{message.id}/reactions/fire.json"
      expect(response.parsed_body["message"]["reactions"]).to eq([])
    end

    it "rejects invalid emoji" do
      sign_in(member)
      put "#{base}/messages/#{message.id}/reactions/%3Cb%3E.json"
      expect(response.status).to eq(422)
    end
  end

  describe "POST /read" do
    it "advances the cursor and reports unread" do
      sign_in(member)
      first = create!(other, "one")
      second = create!(other, "two")

      post "#{base}/read.json", params: { message_id: first.id }
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "last_read_message_id" => first.id,
        "unread_count" => 1,
      )

      post "#{base}/read.json", params: { message_id: second.id }
      expect(response.parsed_body["unread_count"]).to eq(0)

      post "#{base}/read.json", params: { message_id: first.id }
      expect(response.parsed_body["last_read_message_id"]).to eq(second.id)
    end
  end

  describe "legacy import" do
    it "is admin-only and reports status" do
      sign_in(member)
      get "#{base}/legacy-import.json"
      expect(response.status).to eq(403)

      sign_in(admin)
      get "#{base}/legacy-import.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include("imported" => 0, "linked_telegram" => 0)

      post "#{base}/legacy-import.json"
      expect(response.status).to eq(403) unless DiscourseDisteleplus::LegacyChatImporter.available?
    end
  end
end
