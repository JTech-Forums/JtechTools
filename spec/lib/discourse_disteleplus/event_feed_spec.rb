# frozen_string_literal: true

require "rails_helper"

# Event feed → conversation: which review-queue items become a system
# message in the room.
RSpec.describe DiscourseDisteleplus::EventFeed do
  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_event_messages = "reviewable_created"
  end

  describe ".reviewable_created" do
    fab!(:flag) { Fabricate(:reviewable_flagged_post) }
    fab!(:queued) { Fabricate(:reviewable_queued_post) }

    it "posts flags and queued posts by default" do
      expect { described_class.reviewable_created(flag) }.to change {
        DiscourseDisteleplus::Message.count
      }.by(1)
      expect { described_class.reviewable_created(queued) }.to change {
        DiscourseDisteleplus::Message.count
      }.by(1)
    end

    it "skips queued posts, and only those, when the switch is off" do
      SiteSetting.disteleplus_event_messages_queued_posts = false
      expect { described_class.reviewable_created(queued) }.not_to change {
        DiscourseDisteleplus::Message.count
      }
      expect { described_class.reviewable_created(flag) }.to change {
        DiscourseDisteleplus::Message.count
      }.by(1)
    end
  end
end
