# frozen_string_literal: true

# The reopen restrictions (mini_mod_can_reopen_topics, tl4_can_reopen_topics)
# must hold on every route to reopening a topic, not just the button: topic
# timers too.
RSpec.describe "Mini-mod reopen restrictions", type: :request do
  fab!(:mini_mod) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:tl4_user) { Fabricate(:trust_level_4, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:closed_topic) { Fabricate(:topic, category: category, closed: true) }
  fab!(:closed_elsewhere) { Fabricate(:topic, category: other_category, closed: true) }

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(mini_mod)
    Fabricate(:category_moderation_group, category: category, group: group)
  end

  def run_open_timer(topic, by_user)
    timer =
      Fabricate(
        :topic_timer,
        topic: topic,
        user: by_user,
        status_type: TopicTimer.types[:open],
        execute_at: 1.minute.ago,
      )
    Jobs::OpenTopic.new.execute(topic_timer_id: timer.id)
    expect(TopicTimer.where(id: timer.id)).not_to exist
    !topic.reload.closed
  end

  describe "open timers" do
    it "don't reopen for a mini-mod by default" do
      expect(run_open_timer(closed_topic, mini_mod)).to eq(false)
    end

    it "reopen once mini-mods may reopen" do
      SiteSetting.mini_mod_can_reopen_topics = true
      SiteSetting.topic_timers_allowed_groups = group.id.to_s
      expect(run_open_timer(closed_topic, mini_mod)).to eq(true)
    end

    it "reopen for staff" do
      expect(run_open_timer(closed_topic, Fabricate(:admin))).to eq(true)
      closed_topic.update!(closed: true)
      expect(run_open_timer(closed_topic, Fabricate(:moderator))).to eq(true)
    end

    it "don't reopen for a TL4 user by default" do
      expect(run_open_timer(closed_elsewhere, tl4_user)).to eq(false)
    end

    it "reopen for TL4 once allowed" do
      SiteSetting.tl4_can_reopen_topics = true
      expect(run_open_timer(closed_elsewhere, tl4_user)).to eq(true)
    end

    it "fall back to core with Mini-mod off" do
      SiteSetting.mini_mod_enabled = false
      expect(run_open_timer(closed_elsewhere, tl4_user)).to eq(true)
    end

    it "need both switches for a TL4 mini-mod" do
      group.add(tl4_user)
      SiteSetting.mini_mod_can_reopen_topics = true
      expect(run_open_timer(closed_topic, tl4_user)).to eq(false)

      closed_topic.update!(closed: true)
      SiteSetting.tl4_can_reopen_topics = true
      expect(run_open_timer(closed_topic, tl4_user)).to eq(true)
    end
  end

  describe "requests" do
    it "refuse reopening through the status endpoint" do
      sign_in(tl4_user)
      put "/t/#{closed_elsewhere.id}/status.json", params: { status: "closed", enabled: "false" }
      expect(response.status).to eq(403)
      expect(closed_elsewhere.reload.closed).to eq(true)
    end

    it "refuse scheduling an open timer" do
      sign_in(tl4_user)
      post "/t/#{closed_elsewhere.id}/timer.json", params: { time: 24, status_type: "open" }
      expect(response.status).to eq(403)
      expect(TopicTimer.where(topic: closed_elsewhere)).not_to exist
    end

    it "still let a TL4 user close a topic, with its small action post" do
      open_topic = Fabricate(:topic, category: other_category)
      Fabricate(:post, topic: open_topic)
      sign_in(tl4_user)
      put "/t/#{open_topic.id}/status.json", params: { status: "closed", enabled: "true" }
      expect(response.status).to eq(200)
      expect(open_topic.reload.closed).to eq(true)
      expect(open_topic.posts.where(action_code: "closed.enabled")).to exist
    end
  end
end
