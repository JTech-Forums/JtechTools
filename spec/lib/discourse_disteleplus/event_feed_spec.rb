# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::EventFeed do
  fab!(:post)
  fab!(:flagger, :user)

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
  end

  describe "review-queue items" do
    it "never narrates them into the conversation" do
      # Staff already get a bell notification per review item; a chat line
      # would be the same report twice.
      expect { PostActionCreator.spam(flagger, post) }.not_to change {
        DiscourseDisteleplus::Message.count
      }
    end

    it "has no handler and is not offered as a choice" do
      expect(described_class).not_to respond_to(:reviewable_created)
      expect(SiteSetting.disteleplus_event_messages).not_to include("reviewable_created")
      choices = SiteSetting.type_supervisor.type_hash(:disteleplus_event_messages)[:choices]
      expect(choices).to be_present
      expect(choices).not_to include("reviewable_created")
    end
  end

  describe "events that do still narrate" do
    it "posts a suspension line as the system user, unbridged and silent" do
      SiteSetting.disteleplus_event_messages = "user_suspended"
      user = Fabricate(:user, username: "troublemaker")

      expect {
        described_class.user_suspended(user: user, suspended_till: nil, reason: "spam")
      }.to change { DiscourseDisteleplus::Message.count }.by(1)

      message = DiscourseDisteleplus::Message.last
      expect(message.user_id).to eq(Discourse.system_user.id)
      expect(message.raw).to include("troublemaker").and include("spam")
    end
  end
end
