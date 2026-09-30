# frozen_string_literal: true

# Moderators don't see every private message or restricted category. None of
# the Mod module's endpoints or alerts may hand them what core keeps hidden,
# and the module switch turns the endpoints off for everyone.
RSpec.describe "Mod module visibility" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_moderator, :moderator)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:pm) { Fabricate(:private_message_topic, user: admin, recipient: user) }
  fab!(:pm_post) do
    Fabricate(:post, topic: pm, user: user, raw: "Secret message between two people")
  end
  fab!(:admin_category) { Fabricate(:private_category, group: Group[:admins]) }
  fab!(:admin_topic) { Fabricate(:topic, category: admin_category, title: "Admin only planning") }
  fab!(:topic) { Fabricate(:topic, title: "An ordinary public topic") }
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_notify_staff_on_topic_notes = true
  end

  describe "topic endpoints" do
    before { sign_in(moderator) }

    it "404 on a private message the moderator can't read" do
      put "/discourse-mod-categories/topic/#{pm.id}.json",
          params: {
            require_reply_approval: true,
            footer_message: "hi",
          }
      expect(response.status).to eq(404)
      expect(pm.reload.custom_fields["mod_topic_require_reply_approval"]).to be_nil

      get "/discourse-mod-categories/topic/#{pm.id}/prompt-checklist.json"
      expect(response.status).to eq(404)
    end

    it "404 on a topic in a category they can't see" do
      post "/discourse-mod-categories/topic/#{admin_topic.id}/note-reply.json",
           params: {
             raw: "hello",
           }
      expect(response.status).to eq(404)
    end

    it "still work on topics they can see" do
      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "Read the rules",
          }
      expect(response.status).to eq(200)
    end
  end

  describe "private note alerts" do
    it "reach only staff who can see the topic" do
      sign_in(admin)
      put "/discourse-mod-categories/topic/#{admin_topic.id}.json",
          params: {
            private_note: "Plan for the vote",
          }
      expect(response.status).to eq(200)

      expect(Notification.where(user: moderator, topic: admin_topic)).to be_empty
    end

    it "keep a note on a hidden topic out of a moderator's notes feed" do
      admin_topic.custom_fields["mod_topic_private_note"] = "Plan for the vote"
      admin_topic.save_custom_fields(true)
      topic.custom_fields["mod_topic_private_note"] = "Public topic note"
      topic.save_custom_fields(true)

      sign_in(moderator)
      get "/discourse-mod-categories/notes-feed.json"
      topic_ids = response.parsed_body["notes"].map { |n| n["topic_id"] }
      expect(topic_ids).to include(topic.id)
      expect(topic_ids).not_to include(admin_topic.id)
    end
  end

  describe "staff event alerts" do
    before { SiteSetting.mod_notify_staff_on_post_actions = true }

    it "don't tell moderators about a deleted private message post" do
      messages = MessageBus.track_publish { PostDestroyer.new(admin, pm_post).destroy }

      expect(Notification.where(user: moderator)).to be_empty
      alert_channels = messages.map(&:channel)
      expect(alert_channels).not_to include("/notification-alert/#{moderator.id}")
    end

    it "still tell other staff about a deleted public post" do
      reply = Fabricate(:post, topic: topic, user: user)
      PostDestroyer.new(moderator, reply).destroy
      expect(Notification.where(user: other_moderator, topic: topic)).to exist
    end
  end

  describe "checklists" do
    fab!(:checked_topic, :topic)

    before do
      SiteSetting.mod_topic_prompt_checklist_enabled = true
      SiteSetting.mod_targeted_checklists_enabled = true
      pm.custom_fields[DiscourseModCategories::TOPIC_PROMPT_CHECKLIST_FIELD] = {
        "version" => 1,
        "mode" => "statement",
        "statement" => "Private conversation rules",
        "items" => [],
      }
      pm.save_custom_fields(true)
    end

    it "don't reveal a hidden topic's checklist" do
      sign_in(moderator)
      get "/discourse-mod-categories/checklist/owed.json", params: { topic_id: pm.id }
      expect(response.status).to eq(200)
      expect(response.body).not_to include("Private conversation rules")
    end

    it "only let the users a targeted checklist names accept it" do
      PluginStore.set(
        DiscourseModCategories::CHECKLIST_STORE_NAMESPACE,
        DiscourseModCategories::TARGETED_CHECKLISTS_KEY,
        [
          {
            "id" => "abc",
            "name" => "Rules",
            "user_ids" => [admin.id],
            "items" => [],
            "version" => 1,
          },
        ],
      )

      sign_in(user)
      post "/discourse-mod-categories/checklist/accept.json",
           params: {
             kind: "targeted",
             id: "abc",
             version: 1,
           }
      expect(response.status).to eq(404)
    end

    it "log an acceptance once, not on every repeat" do
      SiteSetting.mod_first_post_checklist_enabled = true
      PluginStore.set(
        DiscourseModCategories::CHECKLIST_STORE_NAMESPACE,
        DiscourseModCategories::CHECKLIST_STORE_KEY,
        { "version" => 2, "items" => [{ "label" => "Be kind" }] },
      )

      sign_in(user)
      3.times do
        post "/discourse-mod-categories/checklist/accept.json",
             params: {
               kind: "global",
               version: 2,
             }
        expect(response.status).to eq(200)
      end

      log =
        PluginStore.get(
          DiscourseModCategories::CHECKLIST_STORE_NAMESPACE,
          DiscourseModCategories::CHECKLIST_LOG_KEY,
        )
      expect(log.count { |e| e["user_id"] == user.id }).to eq(1)
    end
  end

  describe "category prompts" do
    fab!(:category)

    before do
      SiteSetting.precheck_new_topic_enabled = true
      category.custom_fields[
        DiscourseModCategories::CATEGORY_NEW_TOPIC_PROMPT_FIELD
      ] = "Search first"
      category.save_custom_fields(true)
      sign_in(moderator)
    end

    it "keep the prompt when only the trust level cap changes" do
      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt_max_tl: 2,
          }
      expect(response.status).to eq(200)
      expect(response.parsed_body["new_topic_prompt"]).to eq("Search first")
    end

    it "can't be set on a category the moderator can't see" do
      put "/discourse-mod-categories/category/#{admin_category.id}.json",
          params: {
            new_topic_prompt: "x",
          }
      expect(response.status).to eq(404)
    end
  end

  describe "whisper conversion" do
    fab!(:admin_post) { Fabricate(:post, topic: topic, user: admin) }

    before do
      SiteSetting.mod_whisper_enabled = true
      SiteSetting.mod_whisper_convert_enabled = true
    end

    it "keeps another staff member's post out of a moderator's hands" do
      sign_in(moderator)
      put "/discourse-mod-categories/post/#{admin_post.id}/whisper.json",
          params: {
            mod_whisper: true,
          }
      expect(response.status).to eq(403)
      expect(DiscourseModCategories::Whisper.whisper?(admin_post.reload)).to eq(false)
    end

    it "logs the change in staff actions" do
      reply = Fabricate(:post, topic: topic, user: user)
      sign_in(moderator)
      put "/discourse-mod-categories/post/#{reply.id}/whisper.json", params: { mod_whisper: true }
      expect(response.status).to eq(200)
      expect(
        UserHistory.where(acting_user_id: moderator.id, custom_type: "mod_post_made_whisper"),
      ).to exist
    end
  end

  it "turns every module endpoint off with the module, admins included" do
    SiteSetting.mod_categories_enabled = false
    sign_in(admin)
    put "/discourse-mod-categories/topic/#{topic.id}.json", params: { footer_message: "hi" }
    expect(response.status).to eq(404)
    get "/discourse-mod-categories/checklist.json"
    expect(response.status).to eq(404)
  end
end
