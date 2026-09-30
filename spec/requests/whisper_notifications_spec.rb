# frozen_string_literal: true

# A whisper's audience gets the whisper notification only — not also the
# replied / mentioned notification PostAlerter would send for the same post.
RSpec.describe "Whisper notifications" do
  fab!(:moderator)
  fab!(:target) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:target_post) { Fabricate(:post, topic: topic, user: target) }

  before do
    Jobs.run_immediately!
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.mod_notify_whisper_targets = true
    SiteSetting.min_post_length = 5
  end

  it "sends one notification to a target it replies to and mentions" do
    sign_in(moderator)
    post "/posts.json",
         params: {
           :topic_id => topic.id,
           :reply_to_post_number => target_post.post_number,
           :raw => "@#{target.username} please have a look at this privately.",
           DiscourseModCategories::POST_WHISPER_ARMED_PARAM => true,
           DiscourseModCategories::POST_WHISPER_TARGETS_FIELD => [target.id],
         }
    expect(response.status).to eq(200)
    whisper = Post.find(response.parsed_body["id"])

    notifications = Notification.where(user: target, topic: topic, post_number: whisper.post_number)
    expect(notifications.count).to eq(1)
    expect(JSON.parse(notifications.first.data)["mod_whisper"]).to eq(true)
  end
end
