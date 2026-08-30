# frozen_string_literal: true

require "rails_helper"

# Read receipts: the read-states endpoint and the read-cursor publish that
# powers the "Seen by" chip.
RSpec.describe "Disteleplus read states" do
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:reader) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:outsider) { Fabricate(:user, trust_level: TrustLevel[0]) }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_read_receipts_enabled = true
    SiteSetting.disteleplus_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
  end

  def message!(user, raw)
    DiscourseDisteleplus::MessageService.new(actor: user).create!(raw: raw)
  end

  describe "GET /jtech-disteleplus/read-states" do
    it "lists other members' cursors, never the requester's" do
      message = message!(member, "hello")
      DiscourseDisteleplus::MessageService.new(actor: reader).mark_read!(message.id)
      DiscourseDisteleplus::MessageService.new(actor: member).mark_read!(message.id)

      sign_in(member)
      get "/jtech-disteleplus/read-states.json"
      expect(response.status).to eq(200)

      states = response.parsed_body["read_states"]
      ids = states.map { |state| state["user_id"] }
      expect(ids).to include(reader.id)
      expect(ids).not_to include(member.id)
      row = states.find { |state| state["user_id"] == reader.id }
      expect(row["last_read_message_id"]).to eq(message.id)
      expect(row["username"]).to eq(reader.username)
      expect(row["avatar_template"]).to be_present
      expect(row["updated_at"]).to be_present
    end

    it "404s when receipts are disabled" do
      SiteSetting.disteleplus_read_receipts_enabled = false
      sign_in(member)
      get "/jtech-disteleplus/read-states.json"
      expect(response.status).to eq(404)
    end

    it "refuses users outside the allowed groups" do
      sign_in(outsider)
      get "/jtech-disteleplus/read-states.json"
      expect(response.status).to eq(403)
    end
  end

  describe "POST /jtech-disteleplus/messages/:id/listened" do
    it "records one listen per user, publishes once, and serializes it" do
      message = message!(member, "a voice note")

      sign_in(reader)
      published =
        MessageBus.track_publish(DiscourseDisteleplus::Publisher::CHANNEL) do
          post "/jtech-disteleplus/messages/#{message.id}/listened.json"
          post "/jtech-disteleplus/messages/#{message.id}/listened.json"
        end
      expect(response.status).to eq(200)
      expect(DiscourseDisteleplus::MessageListen.where(message_id: message.id).count).to eq(1)

      listen_events = published.select { |m| m.data[:type] == "listened" }
      expect(listen_events.length).to eq(1)
      expect(listen_events.first.data[:user_id]).to eq(reader.id)

      serialized = DiscourseDisteleplus::MessageSerializer.serialize(message.reload, viewer: member)
      expect(serialized[:listened_by].map { |u| u[:id] }).to eq([reader.id])
      expect(serialized[:listened_by].first[:listened_at]).to be_present
    end

    it "ignores the author's own plays" do
      message = message!(member, "self listen")
      sign_in(member)
      post "/jtech-disteleplus/messages/#{message.id}/listened.json"
      expect(response.status).to eq(200)
      expect(DiscourseDisteleplus::MessageListen.count).to eq(0)
    end

    it "404s when receipts are disabled" do
      SiteSetting.disteleplus_read_receipts_enabled = false
      message = message!(member, "off")
      sign_in(reader)
      post "/jtech-disteleplus/messages/#{message.id}/listened.json"
      expect(response.status).to eq(404)
    end
  end

  describe "read-cursor publish" do
    it "publishes an advance to the conversation channel" do
      message = message!(member, "watch me get read")
      Discourse.redis.del("disteleplus:read-pub:#{reader.id}")

      published =
        MessageBus.track_publish(DiscourseDisteleplus::Publisher::CHANNEL) do
          DiscourseDisteleplus::MessageService.new(actor: reader).mark_read!(message.id)
        end
      read_events = published.select { |m| m.data[:type] == "read" }
      expect(read_events.length).to eq(1)
      expect(read_events.first.data[:user_id]).to eq(reader.id)
      expect(read_events.first.data[:last_read_message_id]).to eq(message.id)
      expect(read_events.first.user_ids).not_to include(reader.id)
    end

    it "does not publish when receipts are disabled" do
      SiteSetting.disteleplus_read_receipts_enabled = false
      message = message!(member, "silent read")
      published =
        MessageBus.track_publish(DiscourseDisteleplus::Publisher::CHANNEL) do
          DiscourseDisteleplus::MessageService.new(actor: reader).mark_read!(message.id)
        end
      expect(published.select { |m| m.data[:type] == "read" }).to be_empty
    end
  end
end
