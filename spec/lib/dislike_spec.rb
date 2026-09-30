# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseNoLikes do
  fab!(:restricted, :category)
  fab!(:open_category, :category)
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:liker) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, category: restricted, user: author) }
  fab!(:post) { Fabricate(:post, topic: topic, user: author) }
  fab!(:open_post) do
    Fabricate(:post, topic: Fabricate(:topic, category: open_category, user: author), user: author)
  end

  before do
    # Core's test setup switches both off; they are what this module shapes.
    PostActionNotifier.enable
    UserActionManager.enable
    SiteSetting.discourse_no_likes_enabled = true
    SiteSetting.no_reactions_category_ids = restricted.id.to_s
  end

  def like(target = post, user = liker)
    result = PostActionCreator.like(user, target)
    expect(result).to be_success
    result.post_action
  end

  def unlike(target = post, user = liker)
    PostActionDestroyer.new(user, target, PostActionType::LIKE_POST_ACTION_ID).perform
  end

  def liked_notifications(target = post)
    Notification.where(
      user_id: author.id,
      topic_id: target.topic_id,
      notification_type: Notification.types[:liked],
    )
  end

  def like_rows(target = post)
    UserAction.where(
      target_post_id: target.id,
      action_type: [UserAction::LIKE, UserAction::WAS_LIKED],
    )
  end

  def stats
    [liker.user_stat.reload.likes_given, author.user_stat.reload.likes_received]
  end

  describe "who can like" do
    it "hides the button when asked" do
      SiteSetting.dislike_hide_like_button = true
      expect(Guardian.new(liker).post_can_act?(post, :like)).to eq(false)
      expect(Guardian.new(liker).post_can_act?(open_post, :like)).to eq(true)
    end

    it "limits liking to the allowed groups" do
      group = Fabricate(:group)
      SiteSetting.dislike_allowed_like_groups = group.id.to_s
      expect(Guardian.new(liker).post_can_act?(post, :like)).to eq(false)

      group.add(liker)
      expect(Guardian.new(liker.reload).post_can_act?(post, :like)).to eq(true)
    end
  end

  context "with the defaults (no history, not counted)" do
    it "tells nobody, records nothing, and keeps the audit row" do
      like

      expect(liked_notifications).to be_empty
      expect(like_rows).to be_empty
      expect(stats).to eq([0, 0])
      expect(
        DiscourseNoLikes::PhantomReaction.where(post: post, user: liker).pluck(:reaction_type),
      ).to eq(["like"])
      expect(post.reload.like_count).to eq(1)
    end

    it "doesn't rebuild a notification when the like is taken back" do
      like
      unlike
      expect(liked_notifications).to be_empty
      expect(stats).to eq([0, 0])
    end

    it "survives liking the same post again" do
      like
      unlike
      expect { like }.not_to raise_error
      expect(DiscourseNoLikes::PhantomReaction.where(post: post, user: liker).count).to eq(1)
    end

    it "leaves other categories alone" do
      like(open_post)
      expect(liked_notifications(open_post).count).to eq(1)
      expect(like_rows(open_post).count).to eq(2)
      expect(stats).to eq([1, 1])
    end

    it "removes a history row left from before the category was restricted" do
      SiteSetting.no_reactions_category_ids = ""
      like
      expect(like_rows.count).to eq(2)

      SiteSetting.no_reactions_category_ids = restricted.id.to_s
      unlike
      expect(like_rows).to be_empty
    end

    it "is off while the master switch is off" do
      SiteSetting.jtech_enabled = false
      like
      expect(liked_notifications.count).to eq(1)
      expect(stats).to eq([1, 1])
    end
  end

  context "with history kept" do
    before { SiteSetting.dislike_show_in_history = true }

    it "notifies and records history but leaves the totals alone" do
      like
      expect(liked_notifications.count).to eq(1)
      expect(like_rows.count).to eq(2)
      expect(stats).to eq([0, 0])

      unlike
      expect(like_rows).to be_empty
      expect(stats).to eq([0, 0])
    end
  end

  context "with phantom likes counted but no history" do
    before { SiteSetting.dislike_count_in_leaderboard = true }

    it "moves the totals without history rows" do
      like
      expect(like_rows).to be_empty
      expect(liked_notifications).to be_empty
      expect(stats).to eq([1, 1])

      unlike
      expect(stats).to eq([0, 0])
    end
  end

  describe "user directory refresh" do
    before { SiteSetting.dislike_show_in_history = true }

    def directory_likes(user)
      DirectoryItem
        .find_by(user: user, period_type: DirectoryItem.period_types[:all])
        .then { |d| [d.likes_given, d.likes_received] }
    end

    it "keeps phantom likes out of the totals core rebuilds from history" do
      like
      like(open_post)

      DirectoryItem.refresh_period!(:all, force: true)

      expect(directory_likes(liker)).to eq([1, 0])
      expect(directory_likes(author)).to eq([0, 1])
      expect(stats).to eq([1, 1])
    end

    it "adds phantom likes back when they count, even without history" do
      SiteSetting.dislike_show_in_history = false
      SiteSetting.dislike_count_in_leaderboard = true
      like

      DirectoryItem.refresh_period!(:all, force: true)
      DirectoryItem.refresh_period!(:weekly, force: true)

      expect(directory_likes(liker)).to eq([1, 0])
      expect(directory_likes(author)).to eq([0, 1])
      expect(
        DirectoryItem.find_by(
          user: author,
          period_type: DirectoryItem.period_types[:weekly],
        ).likes_received,
      ).to eq(1)
      expect(stats).to eq([1, 1])
    end

    it "is stable across repeated refreshes" do
      like
      3.times { DirectoryItem.refresh_period!(:all, force: true) }
      expect(directory_likes(author)).to eq([0, 0])
    end
  end

  describe "purge job" do
    it "applies the settings to likes made before the category was restricted" do
      SiteSetting.no_reactions_category_ids = ""
      like
      like(open_post)
      expect(liked_notifications.count).to eq(1)

      SiteSetting.no_reactions_category_ids = restricted.id.to_s
      Jobs::PurgePhantomReactions.new.execute({})

      expect(like_rows).to be_empty
      expect(liked_notifications).to be_empty
      expect(liked_notifications(open_post).count).to eq(1)
      expect(stats).to eq([1, 1])
      expect(DiscourseNoLikes::PhantomReaction.where(post: post).count).to eq(1)
    end
  end

  describe "discourse-reactions", if: defined?(DiscourseReactions) do
    before do
      SiteSetting.discourse_reactions_enabled = true
      SiteSetting.discourse_reactions_enabled_reactions = "+1|laughing"
    end

    def react(value, target = post)
      DiscourseReactions::ReactionManager.new(
        reaction_value: value,
        user: liker,
        post: target,
      ).toggle!
    end

    def reaction_notifications(target = post)
      Notification.where(
        user_id: author.id,
        topic_id: target.topic_id,
        notification_type: Notification.types[:reaction],
      )
    end

    it "doesn't send the reacted notification in restricted categories" do
      react("laughing")
      expect(reaction_notifications).to be_empty
      expect(DiscourseNoLikes::PhantomReaction.where(post: post).pluck(:reaction_type)).to eq(
        ["laughing"],
      )

      react("laughing")
      expect(reaction_notifications).to be_empty
    end

    it "still notifies elsewhere" do
      react("laughing", open_post)
      expect(reaction_notifications(open_post).count).to eq(1)
    end

    it "blocks reactions along with likes" do
      SiteSetting.dislike_hide_like_button = true
      expect { react("laughing") }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
