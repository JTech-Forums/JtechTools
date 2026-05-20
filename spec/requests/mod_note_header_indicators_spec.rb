# frozen_string_literal: true

require "rails_helper"

# Coverage for the data backing the moderator-notes header pip + browser-tab
# title prefix:
#   - `mod_note_unread_count` reflects the right number across states.
#   - Setting a note (and replying) publishes a `+1` bump on the dedicated
#     `/mod-note-unread-count/{user_id}` MessageBus channel.
#   - Marking the feed as seen publishes a `reset` on the same channel and
#     drives the serializer count back to zero.
RSpec.describe "Moderator-note header indicators" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_moderator, :moderator)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  before { SiteSetting.mod_categories_enabled = true }

  describe "current-user serializer: mod_note_unread_count" do
    it "reports zero when no topic has note activity" do
      sign_in(moderator)

      get "/session/current.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["current_user"]["mod_note_unread_count"]).to eq(0)
    end

    it "reports the right count for unseen note activity" do
      topic.custom_fields["mod_topic_private_note_activity_at"] = Time.zone.now.iso8601
      topic.save_custom_fields(true)

      sign_in(moderator)

      get "/session/current.json"

      expect(response.parsed_body["current_user"]["mod_note_unread_count"]).to be >= 1
    end

    it "drops back to zero after the staff member marks the feed seen" do
      topic.custom_fields["mod_topic_private_note_activity_at"] = 2.days.ago.iso8601
      topic.save_custom_fields(true)

      sign_in(moderator)
      post "/discourse-mod-categories/notes-feed/seen.json"
      expect(response.status).to eq(200)

      get "/session/current.json"
      expect(response.parsed_body["current_user"]["mod_note_unread_count"]).to eq(0)
    end

    it "is always zero for a non-staff user" do
      topic.custom_fields["mod_topic_private_note_activity_at"] = Time.zone.now.iso8601
      topic.save_custom_fields(true)

      sign_in(user)

      get "/session/current.json"
      expect(response.parsed_body["current_user"]["mod_note_unread_count"]).to eq(0)
    end
  end

  describe "MessageBus: /mod-note-unread-count" do
    def set_note(raw = "Heads up, staff.")
      put "/discourse-mod-categories/topic/#{topic.id}.json", params: { private_note: raw }
    end

    it "publishes a +1 bump to every other staff member on a new note" do
      sign_in(moderator)

      messages =
        MessageBus
          .track_publish { set_note }
          .select { |m| m.channel.start_with?("/mod-note-unread-count/") }

      channels = messages.map(&:channel)
      expect(channels).to include("/mod-note-unread-count/#{admin.id}")
      expect(channels).to include("/mod-note-unread-count/#{other_moderator.id}")
      expect(channels).not_to include("/mod-note-unread-count/#{moderator.id}")

      payload = messages.first.data
      expect(payload[:delta]).to eq(1)
    end

    it "publishes a +1 bump on a note reply too" do
      topic.custom_fields["mod_topic_private_note"] = "Initial note."
      topic.save_custom_fields(true)
      sign_in(moderator)

      messages =
        MessageBus
          .track_publish do
            post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
                 params: {
                   raw: "Following up.",
                 }
          end
          .select { |m| m.channel.start_with?("/mod-note-unread-count/") }

      channels = messages.map(&:channel)
      expect(channels).to include("/mod-note-unread-count/#{admin.id}")
      expect(channels).to include("/mod-note-unread-count/#{other_moderator.id}")
    end

    it "publishes a reset when the staff member marks the feed as seen" do
      sign_in(moderator)

      messages =
        MessageBus
          .track_publish { post "/discourse-mod-categories/notes-feed/seen.json" }
          .select { |m| m.channel.start_with?("/mod-note-unread-count/") }

      expect(messages.map(&:channel)).to eq(["/mod-note-unread-count/#{moderator.id}"])
      expect(messages.first.data[:reset]).to eq(true)
    end

    it "marks the staff member's mod-note Notification rows as read" do
      # Seed two unread mod-note notifications and one unrelated custom
      # notification — only the mod-note rows should flip to read.
      mod_note_rows =
        2.times.map do
          Notification.create!(
            user_id: moderator.id,
            notification_type: Notification.types[:custom],
            read: false,
            data: { mod_note: true, message: "x" }.to_json,
          )
        end
      unrelated =
        Notification.create!(
          user_id: moderator.id,
          notification_type: Notification.types[:custom],
          read: false,
          data: { message: "not a mod note" }.to_json,
        )

      sign_in(moderator)
      post "/discourse-mod-categories/notes-feed/seen.json"
      expect(response.status).to eq(200)

      mod_note_rows.each { |n| expect(n.reload.read).to eq(true) }
      expect(unrelated.reload.read).to eq(false)
    end
  end
end
