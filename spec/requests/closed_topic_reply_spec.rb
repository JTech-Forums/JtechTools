# frozen_string_literal: true

# End-to-end coverage for the closed-topic reply restriction. Hits the
# regular post-creation endpoint (POST /posts.json) as different user
# classes and verifies the server enforces the mini_mod_can_post_in_closed_topics
# setting on the actual user-facing reply path -- not just the Guardian unit.
RSpec.describe "Replying on closed topics as a mini-mod" do
  # refresh_auto_groups is required so the user lands in the trust-level
  # auto groups; without it, the post-creation endpoint enqueues replies
  # for review instead of creating them, and the test can't observe the
  # close-topic restriction directly.
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:category)
  fab!(:closed_topic) { Fabricate(:topic, category: category, closed: true) }
  fab!(:open_topic) { Fabricate(:topic, category: category) }
  fab!(:other_category, :category)
  fab!(:closed_in_other_category) { Fabricate(:topic, category: other_category, closed: true) }

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: category, group: group)
    # The closed topics need at least one post so PostCreator can attach a reply.
    Fabricate(:post, topic: closed_topic)
    Fabricate(:post, topic: open_topic)
    Fabricate(:post, topic: closed_in_other_category)
  end

  context "with the default restriction (mini_mod_can_post_in_closed_topics: false)" do
    before { sign_in(user) }

    it "blocks the mini-mod from replying on a closed topic in their moderated category" do
      expect {
        post "/posts.json",
             params: {
               raw: "trying to reply on a closed topic",
               topic_id: closed_topic.id,
             }
      }.not_to change { closed_topic.reload.posts_count }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "still allows the mini-mod to reply on an open topic in their moderated category" do
      expect {
        post "/posts.json", params: { raw: "replying on an open topic", topic_id: open_topic.id }
      }.to change { open_topic.reload.posts_count }.by(1)
      expect(response.status).to eq(200)
    end

    it "does not affect closed topics in categories the mini-mod does not moderate (still blocked by core)" do
      expect {
        post "/posts.json",
             params: {
               raw: "trying to reply elsewhere",
               topic_id: closed_in_other_category.id,
             }
      }.not_to change { closed_in_other_category.reload.posts_count }
      expect(response.status).to eq(422)
    end
  end

  context "when mini_mod_can_post_in_closed_topics is enabled" do
    before do
      SiteSetting.mini_mod_can_post_in_closed_topics = true
      sign_in(user)
    end

    it "allows the mini-mod to reply on a closed topic in their moderated category" do
      expect {
        post "/posts.json", params: { raw: "now I can reply", topic_id: closed_topic.id }
      }.to change { closed_topic.reload.posts_count }.by(1)
      expect(response.status).to eq(200)
    end

    it "still does not let them reply on closed topics outside their moderated categories" do
      expect {
        post "/posts.json",
             params: {
               raw: "trying again elsewhere",
               topic_id: closed_in_other_category.id,
             }
      }.not_to change { closed_in_other_category.reload.posts_count }
      expect(response.status).to eq(422)
    end
  end

  context "as a site moderator" do
    fab!(:moderator)

    before { sign_in(moderator) }

    it "can reply on closed topics regardless of the plugin restriction" do
      post "/posts.json", params: { raw: "moderator reply", topic_id: closed_topic.id }
      expect(response.status).to eq(200)
    end
  end

  context "as an admin" do
    fab!(:admin)

    before { sign_in(admin) }

    it "can reply on closed topics regardless of the plugin restriction" do
      post "/posts.json", params: { raw: "admin reply", topic_id: closed_topic.id }
      expect(response.status).to eq(200)
    end
  end

  context "when the plugin is disabled" do
    before do
      SiteSetting.mini_mod_enabled = false
      sign_in(user)
    end

    it "falls back to core behavior, allowing the mini-mod to reply on closed topics they moderate" do
      post "/posts.json", params: { raw: "plugin disabled", topic_id: closed_topic.id }
      expect(response.status).to eq(200)
    end
  end

  # Core lets any TL4 user reply on a closed topic via the "trusted" branch in
  # Guardian::TopicGuardian#can_create_post_on_topic?. The tl4_can_post_in_closed_topics
  # setting clamps that down site-wide, regardless of whether the topic is in a
  # mini-mod category.
  context "as a trust level 4 user (not a mini-mod)" do
    fab!(:tl4_user) { Fabricate(:trust_level_4, refresh_auto_groups: true) }

    context "with the default restriction (tl4_can_post_in_closed_topics: false)" do
      before { sign_in(tl4_user) }

      it "blocks the TL4 user from replying on a closed topic in a mini-mod category" do
        expect {
          post "/posts.json",
               params: {
                 raw: "tl4 trying to reply on a closed topic",
                 topic_id: closed_topic.id,
               }
        }.not_to change { closed_topic.reload.posts_count }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "blocks the TL4 user from replying on a closed topic in any other category too" do
        expect {
          post "/posts.json",
               params: {
                 raw: "tl4 trying elsewhere",
                 topic_id: closed_in_other_category.id,
               }
        }.not_to change { closed_in_other_category.reload.posts_count }
        expect(response.status).to eq(422)
      end

      it "still allows the TL4 user to reply on open topics" do
        expect {
          post "/posts.json",
               params: {
                 raw: "tl4 replying on an open topic",
                 topic_id: open_topic.id,
               }
        }.to change { open_topic.reload.posts_count }.by(1)
        expect(response.status).to eq(200)
      end
    end

    context "when tl4_can_post_in_closed_topics is enabled" do
      before do
        SiteSetting.tl4_can_post_in_closed_topics = true
        sign_in(tl4_user)
      end

      it "allows the TL4 user to reply on closed topics anywhere" do
        expect {
          post "/posts.json",
               params: {
                 raw: "tl4 reply allowed",
                 topic_id: closed_in_other_category.id,
               }
        }.to change { closed_in_other_category.reload.posts_count }.by(1)
        expect(response.status).to eq(200)
      end
    end

    context "when the plugin is disabled" do
      before do
        SiteSetting.mini_mod_enabled = false
        sign_in(tl4_user)
      end

      it "falls back to core, which allows TL4 users to reply on closed topics" do
        post "/posts.json",
             params: {
               raw: "plugin disabled tl4 reply",
               topic_id: closed_in_other_category.id,
             }
        expect(response.status).to eq(200)
      end
    end
  end
end
