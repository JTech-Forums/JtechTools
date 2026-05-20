# frozen_string_literal: true

# Exercises the timer-based reopen path: Jobs::OpenTopic invokes
# Guardian#can_open_topic? when a topic timer fires. The plugin's
# can_open_topic? override should block the job from reopening when the
# user is a mini-mod and the restriction is on, and allow it when the
# restriction is off.
RSpec.describe Jobs::OpenTopic do
  fab!(:user)
  fab!(:group)
  fab!(:category)
  fab!(:closed_topic) { Fabricate(:topic, category: category, closed: true) }

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: category, group: group)
  end

  def schedule_open_timer(by_user)
    Fabricate(
      :topic_timer,
      topic: closed_topic,
      user: by_user,
      status_type: TopicTimer.types[:open],
      execute_at: 1.minute.ago,
    )
  end

  describe "with the default restriction (mini_mod_can_reopen_topics: false)" do
    it "destroys the timer and leaves the topic closed when scheduled by a mini-mod" do
      timer = schedule_open_timer(user)
      described_class.new.execute(topic_timer_id: timer.id)
      expect(closed_topic.reload.closed).to eq(true)
      expect(TopicTimer.where(id: timer.id)).not_to exist
    end

    it "still reopens the topic when the timer is scheduled by an admin" do
      timer = schedule_open_timer(Fabricate(:admin))
      described_class.new.execute(topic_timer_id: timer.id)
      expect(closed_topic.reload.closed).to eq(false)
    end

    it "still reopens the topic when the timer is scheduled by a moderator" do
      timer = schedule_open_timer(Fabricate(:moderator))
      described_class.new.execute(topic_timer_id: timer.id)
      expect(closed_topic.reload.closed).to eq(false)
    end
  end

  context "when mini_mod_can_reopen_topics is enabled" do
    before { SiteSetting.mini_mod_can_reopen_topics = true }

    it "lets the mini-mod's timer reopen the topic" do
      timer = schedule_open_timer(user)
      described_class.new.execute(topic_timer_id: timer.id)
      expect(closed_topic.reload.closed).to eq(false)
    end
  end

  context "when the plugin is disabled" do
    before { SiteSetting.mini_mod_enabled = false }

    it "lets the mini-mod's timer reopen the topic (falls back to core behavior)" do
      timer = schedule_open_timer(user)
      described_class.new.execute(topic_timer_id: timer.id)
      expect(closed_topic.reload.closed).to eq(false)
    end
  end

  # Parallel coverage for the tl4_can_reopen_topics gate. The Guardian unit
  # spec proves can_open_topic? returns false for TL4 users; this proves
  # Jobs::OpenTopic actually honours that and destroys the timer instead of
  # reopening when a TL4 user (who is not a mini-mod) scheduled the timer.
  describe "TL4 timer reopen path" do
    fab!(:tl4_user, :trust_level_4)
    fab!(:other_category, :category)
    fab!(:closed_in_other_category) { Fabricate(:topic, category: other_category, closed: true) }

    def schedule_open_timer_for(topic, by_user)
      Fabricate(
        :topic_timer,
        topic: topic,
        user: by_user,
        status_type: TopicTimer.types[:open],
        execute_at: 1.minute.ago,
      )
    end

    context "with the default restriction (tl4_can_reopen_topics: false)" do
      it "destroys the timer and leaves the topic closed when scheduled by a TL4 user" do
        timer = schedule_open_timer_for(closed_in_other_category, tl4_user)
        described_class.new.execute(topic_timer_id: timer.id)
        expect(closed_in_other_category.reload.closed).to eq(true)
        expect(TopicTimer.where(id: timer.id)).not_to exist
      end

      it "blocks the TL4 timer even on a topic in a mini-mod category" do
        timer = schedule_open_timer_for(closed_topic, tl4_user)
        described_class.new.execute(topic_timer_id: timer.id)
        expect(closed_topic.reload.closed).to eq(true)
        expect(TopicTimer.where(id: timer.id)).not_to exist
      end
    end

    context "when tl4_can_reopen_topics is enabled" do
      before { SiteSetting.tl4_can_reopen_topics = true }

      it "lets the TL4 user's timer reopen the topic" do
        timer = schedule_open_timer_for(closed_in_other_category, tl4_user)
        described_class.new.execute(topic_timer_id: timer.id)
        expect(closed_in_other_category.reload.closed).to eq(false)
      end
    end

    context "when the plugin is disabled" do
      before { SiteSetting.mini_mod_enabled = false }

      it "lets the TL4 user's timer reopen the topic (falls back to core behavior)" do
        timer = schedule_open_timer_for(closed_in_other_category, tl4_user)
        described_class.new.execute(topic_timer_id: timer.id)
        expect(closed_in_other_category.reload.closed).to eq(false)
      end
    end

    # A TL4 user who is also a mini-mod must clear both gates for the timer
    # to actually reopen the topic.
    describe "TL4 user who is also a mini-mod" do
      fab!(:tl4_mini_mod, :trust_level_4)

      before { group.add(tl4_mini_mod) }

      it "destroys the timer when neither gate is open" do
        timer = schedule_open_timer_for(closed_topic, tl4_mini_mod)
        described_class.new.execute(topic_timer_id: timer.id)
        expect(closed_topic.reload.closed).to eq(true)
        expect(TopicTimer.where(id: timer.id)).not_to exist
      end

      it "destroys the timer when only the mini_mod gate is open (TL4 still blocks)" do
        SiteSetting.mini_mod_can_reopen_topics = true
        timer = schedule_open_timer_for(closed_topic, tl4_mini_mod)
        described_class.new.execute(topic_timer_id: timer.id)
        expect(closed_topic.reload.closed).to eq(true)
      end

      it "destroys the timer when only the tl4 gate is open (mini_mod still blocks)" do
        SiteSetting.tl4_can_reopen_topics = true
        timer = schedule_open_timer_for(closed_topic, tl4_mini_mod)
        described_class.new.execute(topic_timer_id: timer.id)
        expect(closed_topic.reload.closed).to eq(true)
      end

      it "reopens the topic when both gates are open" do
        SiteSetting.mini_mod_can_reopen_topics = true
        SiteSetting.tl4_can_reopen_topics = true
        timer = schedule_open_timer_for(closed_topic, tl4_mini_mod)
        described_class.new.execute(topic_timer_id: timer.id)
        expect(closed_topic.reload.closed).to eq(false)
      end
    end
  end
end
