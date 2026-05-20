# frozen_string_literal: true

require "rails_helper"

# Verifies the per-topic "require approval for replies" feature: when a
# moderator flags a topic, replies route to the review queue via the
# NewPostManager handler; staff still post directly, and new topics are
# unaffected.
RSpec.describe "Per-topic reply approval" do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:op) { Fabricate(:post, topic: topic) }
  fab!(:replier) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:moderator)

  before { SiteSetting.mod_categories_enabled = true }

  def reply_as(user)
    NewPostManager.new(
      user,
      raw: "This is a reply that is comfortably long enough to validate.",
      topic_id: topic.id,
    ).perform
  end

  def require_approval!
    topic.custom_fields["mod_topic_require_reply_approval"] = true
    topic.save_custom_fields(true)
  end

  it "enqueues a reply for review when the topic requires approval" do
    require_approval!

    result = reply_as(replier)

    expect(result.action).to eq(:enqueued)
    expect(ReviewableQueuedPost.where(topic_id: topic.id).count).to eq(1)
  end

  it "does not enqueue replies when the topic does not require approval" do
    result = reply_as(replier)

    expect(result.action).not_to eq(:enqueued)
    expect(ReviewableQueuedPost.where(topic_id: topic.id)).to be_empty
  end

  it "lets staff reply directly even when approval is required" do
    require_approval!

    result = reply_as(moderator)

    expect(result.action).not_to eq(:enqueued)
  end

  it "does not affect new topics" do
    require_approval!

    result =
      NewPostManager.new(
        replier,
        raw: "A brand new topic body that is long enough to validate.",
        title: "A brand new topic title goes here",
        category: category.id,
      ).perform

    expect(result.action).not_to eq(:enqueued)
  end
end
