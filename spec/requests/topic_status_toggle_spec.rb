# frozen_string_literal: true

# End-to-end coverage for the closed-topic restrictions: actually hits the
# topic status endpoint as a mini-mod and verifies the controller blocks
# reopens (via ensure_can_close_topic! -> can_close_topic?) while still
# allowing closes. This complements the Guardian unit specs by exercising
# the full HTTP path that the UI button uses.
RSpec.describe "Topic status toggle for mini-mods" do
  fab!(:user)
  fab!(:group)
  fab!(:category)
  fab!(:open_topic) { Fabricate(:topic, category: category) }
  fab!(:closed_topic) { Fabricate(:topic, category: category, closed: true) }

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: category, group: group)
  end

  describe "PUT /t/:topic_id/status (manual close/reopen)" do
    before { sign_in(user) }

    it "blocks mini-mods from reopening a closed topic by default" do
      put "/t/#{closed_topic.id}/status.json", params: { status: "closed", enabled: "false" }
      expect(response.status).to eq(403)
      expect(closed_topic.reload.closed).to eq(true)
    end

    it "still allows mini-mods to close an open topic in their category" do
      put "/t/#{open_topic.id}/status.json", params: { status: "closed", enabled: "true" }
      expect(response.status).to eq(200)
      expect(open_topic.reload.closed).to eq(true)
    end

    # Regression: TopicStatusUpdater synchronously creates a "@user closed
    # this topic" small action post via add_moderator_post. Without the
    # Topic#add_moderator_post override that passes skip_guardian: true, our
    # can_create_post_on_topic? override blocks the bookkeeping post creation
    # because the topic was just marked closed.
    it "still creates the close-announcement small action post when a mini-mod closes a topic" do
      put "/t/#{open_topic.id}/status.json", params: { status: "closed", enabled: "true" }
      expect(response.status).to eq(200)

      open_topic.reload
      announcement = open_topic.posts.where(post_type: Post.types[:small_action]).order(:id).last
      expect(announcement).to be_present
      expect(announcement.action_code).to eq("closed.enabled")
      expect(announcement.user_id).to eq(user.id)
    end

    context "when mini_mod_can_reopen_topics is enabled" do
      before { SiteSetting.mini_mod_can_reopen_topics = true }

      it "allows mini-mods to reopen a closed topic in their category" do
        put "/t/#{closed_topic.id}/status.json", params: { status: "closed", enabled: "false" }
        expect(response.status).to eq(200)
        expect(closed_topic.reload.closed).to eq(false)
      end
    end
  end

  describe "scoping" do
    fab!(:other_category, :category)
    fab!(:closed_in_other_category) { Fabricate(:topic, category: other_category, closed: true) }
    fab!(:open_in_other_category) { Fabricate(:topic, category: other_category) }

    before { sign_in(user) }

    it "blocks mini-mods from closing topics in categories they do not moderate" do
      put "/t/#{open_in_other_category.id}/status.json",
          params: {
            status: "closed",
            enabled: "true",
          }
      expect(response.status).to eq(403)
      expect(open_in_other_category.reload.closed).to eq(false)
    end

    it "blocks mini-mods from reopening topics in categories they do not moderate" do
      put "/t/#{closed_in_other_category.id}/status.json",
          params: {
            status: "closed",
            enabled: "false",
          }
      expect(response.status).to eq(403)
      expect(closed_in_other_category.reload.closed).to eq(true)
    end
  end

  describe "archive flow (regression for the small-action skip_guardian fix)" do
    before { sign_in(user) }

    it "lets mini-mods archive a topic in their category and creates the announcement post" do
      put "/t/#{open_topic.id}/status.json", params: { status: "archived", enabled: "true" }
      expect(response.status).to eq(200)
      expect(open_topic.reload.archived).to eq(true)

      announcement = open_topic.posts.where(post_type: Post.types[:small_action]).order(:id).last
      expect(announcement).to be_present
      expect(announcement.action_code).to eq("archived.enabled")
      expect(announcement.user_id).to eq(user.id)
    end
  end

  describe "site moderators are unaffected" do
    fab!(:moderator)

    before { sign_in(moderator) }

    it "can reopen closed topics regardless of the plugin restriction" do
      put "/t/#{closed_topic.id}/status.json", params: { status: "closed", enabled: "false" }
      expect(response.status).to eq(200)
      expect(closed_topic.reload.closed).to eq(false)
    end

    it "still produces the reopen announcement post when reopening" do
      put "/t/#{closed_topic.id}/status.json", params: { status: "closed", enabled: "false" }
      expect(response.status).to eq(200)

      announcement =
        closed_topic.reload.posts.where(post_type: Post.types[:small_action]).order(:id).last
      expect(announcement).to be_present
      expect(announcement.action_code).to eq("closed.disabled")
      expect(announcement.user_id).to eq(moderator.id)
    end
  end

  describe "admins are unaffected" do
    fab!(:admin)

    before { sign_in(admin) }

    it "can reopen closed topics and produces the announcement post" do
      put "/t/#{closed_topic.id}/status.json", params: { status: "closed", enabled: "false" }
      expect(response.status).to eq(200)
      expect(closed_topic.reload.closed).to eq(false)

      announcement = closed_topic.posts.where(post_type: Post.types[:small_action]).order(:id).last
      expect(announcement).to be_present
      expect(announcement.action_code).to eq("closed.disabled")
    end
  end

  # Core lets TL4 users reopen any visible topic via
  # Guardian::TopicGuardian#can_perform_action_available_to_group_moderators?.
  # The tl4_can_reopen_topics setting clamps that down site-wide.
  describe "trust level 4 users (not mini-mods)" do
    fab!(:tl4_user, :trust_level_4)
    fab!(:other_category, :category)
    fab!(:closed_in_other_category) { Fabricate(:topic, category: other_category, closed: true) }

    before { sign_in(tl4_user) }

    context "with the default restriction (tl4_can_reopen_topics: false)" do
      it "blocks TL4 users from reopening a closed topic in a mini-mod category" do
        put "/t/#{closed_topic.id}/status.json", params: { status: "closed", enabled: "false" }
        expect(response.status).to eq(403)
        expect(closed_topic.reload.closed).to eq(true)
      end

      it "blocks TL4 users from reopening a closed topic in any other category too" do
        put "/t/#{closed_in_other_category.id}/status.json",
            params: {
              status: "closed",
              enabled: "false",
            }
        expect(response.status).to eq(403)
        expect(closed_in_other_category.reload.closed).to eq(true)
      end

      it "still allows TL4 users to close an open topic (closing isn't restricted)" do
        put "/t/#{open_topic.id}/status.json", params: { status: "closed", enabled: "true" }
        expect(response.status).to eq(200)
        expect(open_topic.reload.closed).to eq(true)
      end
    end

    context "when tl4_can_reopen_topics is enabled" do
      before { SiteSetting.tl4_can_reopen_topics = true }

      it "allows TL4 users to reopen closed topics" do
        put "/t/#{closed_in_other_category.id}/status.json",
            params: {
              status: "closed",
              enabled: "false",
            }
        expect(response.status).to eq(200)
        expect(closed_in_other_category.reload.closed).to eq(false)
      end
    end

    context "when the plugin is disabled" do
      before { SiteSetting.mini_mod_enabled = false }

      it "falls back to core, which allows TL4 users to reopen closed topics" do
        put "/t/#{closed_in_other_category.id}/status.json",
            params: {
              status: "closed",
              enabled: "false",
            }
        expect(response.status).to eq(200)
        expect(closed_in_other_category.reload.closed).to eq(false)
      end
    end
  end
end
