# frozen_string_literal: true

require "rails_helper"

# Contract for the per-feature moderator toggles: every grant the mod
# modules hand to moderators is individually revocable from settings, and
# the three security fixes hold — badge-member enumeration is staff-only,
# note entries belong to their author unless the site opts otherwise, and
# targeted checklists can never gate an admin.
RSpec.describe "Moderator feature toggles" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_moderator, :moderator)
  fab!(:user)
  fab!(:topic)
  fab!(:badge) { Fabricate(:badge, name: "ToggleBadge") }

  before do
    SiteSetting.mod_categories_enabled = true
    Group.refresh_automatic_groups!
  end

  describe "badge-members endpoint (security fix)" do
    before { BadgeGranter.grant(badge, user) }

    it "forbids regular users — even ones who can send PMs" do
      sign_in(user)
      get "/discourse-mod-categories/badge-members/#{badge.id}.json"
      expect(response.status).to eq(403)
    end

    it "still serves moderators" do
      sign_in(moderator)
      get "/discourse-mod-categories/badge-members/#{badge.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["usernames"]).to include(user.username)
    end

    it "404s when the feature toggle is off" do
      SiteSetting.mod_pm_badge_group_enabled = false
      sign_in(moderator)
      get "/discourse-mod-categories/badge-members/#{badge.id}.json"
      expect(response.status).to eq(404)
    end
  end

  describe "note-entry ownership (security fix)" do
    def seed_reply_as(author)
      sign_in(author)
      put "/discourse-mod-categories/topic/#{topic.id}.json", params: { private_note: "The note." }
      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "Author's reply.",
           }
      topic.reload.custom_fields["mod_topic_private_note_replies"].first["id"]
    end

    it "stops a moderator from editing another moderator's reply by default" do
      reply_id = seed_reply_as(moderator)

      sign_in(other_moderator)
      put "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
          params: {
            reply_id: reply_id,
            raw: "Rewritten.",
          }
      expect(response.status).to eq(403)

      delete "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
             params: {
               reply_id: reply_id,
             }
      expect(response.status).to eq(403)
    end

    it "allows it when mod_moderators_can_edit_others_notes is on" do
      SiteSetting.mod_moderators_can_edit_others_notes = true
      reply_id = seed_reply_as(moderator)

      sign_in(other_moderator)
      put "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
          params: {
            reply_id: reply_id,
            raw: "Rewritten.",
          }
      expect(response.status).to eq(200)
    end

    it "always allows admins" do
      reply_id = seed_reply_as(moderator)

      sign_in(admin)
      put "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
          params: {
            reply_id: reply_id,
            raw: "Admin edit.",
          }
      expect(response.status).to eq(200)
    end

    it "stops a non-author moderator from deleting the whole note by default" do
      seed_reply_as(moderator)

      sign_in(other_moderator)
      delete "/discourse-mod-categories/topic/#{topic.id}/note.json"
      expect(response.status).to eq(403)
    end
  end

  describe "targeted checklists never gate admins (security fix)" do
    it "returns no owed targeted checklist for an admin even when targeted" do
      PluginStore.set(
        DiscourseModCategories::CHECKLIST_STORE_NAMESPACE,
        DiscourseModCategories::TARGETED_CHECKLISTS_KEY,
        [
          {
            "id" => "block-admin",
            "name" => "Gotcha",
            "user_ids" => [admin.id],
            "items" => [{ "label" => "Read", "url" => "" }],
            "version" => 1,
            "button_label" => "OK",
          },
        ],
      )

      expect(DiscourseModCategories.owed_checklist_for(admin)).to be_nil
    end

    it "still targets moderators" do
      PluginStore.set(
        DiscourseModCategories::CHECKLIST_STORE_NAMESPACE,
        DiscourseModCategories::TARGETED_CHECKLISTS_KEY,
        [
          {
            "id" => "mods",
            "name" => "Mods",
            "user_ids" => [moderator.id],
            "items" => [{ "label" => "Read", "url" => "" }],
            "version" => 1,
            "button_label" => "OK",
          },
        ],
      )

      expect(DiscourseModCategories.owed_checklist_for(moderator)).to be_present
    end

    it "returns nothing when the targeted feature is off" do
      SiteSetting.mod_targeted_checklists_enabled = false
      PluginStore.set(
        DiscourseModCategories::CHECKLIST_STORE_NAMESPACE,
        DiscourseModCategories::TARGETED_CHECKLISTS_KEY,
        [
          {
            "id" => "mods",
            "name" => "Mods",
            "user_ids" => [moderator.id],
            "items" => [{ "label" => "Read", "url" => "" }],
            "version" => 1,
            "button_label" => "OK",
          },
        ],
      )

      expect(DiscourseModCategories.owed_checklist_for(moderator)).to be_nil
    end
  end

  describe "per-feature endpoint toggles" do
    it "404s pinning a post when mod_pin_post_enabled is off" do
      SiteSetting.mod_pin_post_enabled = false
      post_record = Fabricate(:post, topic: topic)
      sign_in(moderator)
      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            pinned_post_id: post_record.id,
          }
      expect(response.status).to eq(404)
    end

    it "404s the notes feed when mod_notes_feed_enabled is off" do
      SiteSetting.mod_notes_feed_enabled = false
      sign_in(moderator)
      get "/discourse-mod-categories/notes-feed.json"
      expect(response.status).to eq(404)
    end

    it "404s private notes when mod_topic_private_notes_enabled is off" do
      SiteSetting.mod_topic_private_notes_enabled = false
      sign_in(moderator)
      put "/discourse-mod-categories/topic/#{topic.id}.json", params: { private_note: "Nope." }
      expect(response.status).to eq(404)
    end

    it "still saves a footer message with its own toggle on" do
      sign_in(moderator)
      put "/discourse-mod-categories/topic/#{topic.id}.json", params: { footer_message: "Hello." }
      expect(response.status).to eq(200)
    end
  end

  describe "moderator category powers" do
    it "revokes category creation when its toggle is off" do
      SiteSetting.mod_moderators_can_create_categories = false
      expect(Guardian.new(moderator).can_create_category?).to eq(false)
    end

    it "grants category creation by default" do
      expect(Guardian.new(moderator).can_create_category?).to eq(true)
    end

    it "revokes category deletion when its toggle is off" do
      SiteSetting.mod_moderators_can_delete_categories = false
      category = Fabricate(:category)
      expect(Guardian.new(moderator).can_delete_category?(category)).to eq(false)
    end
  end

  describe "serializer gating" do
    fab!(:footer_topic, :topic)

    before do
      footer_topic.custom_fields["mod_topic_footer_message"] = "Footer!"
      footer_topic.save_custom_fields(true)
      Fabricate(:post, topic: footer_topic)
    end

    it "serializes the footer while the module is enabled" do
      sign_in(user)
      get "/t/#{footer_topic.id}.json"
      expect(response.parsed_body["mod_topic_footer_message"]).to eq("Footer!")
    end

    it "drops the footer when the module master switch is off" do
      SiteSetting.mod_categories_enabled = false
      sign_in(user)
      get "/t/#{footer_topic.id}.json"
      expect(response.parsed_body).not_to have_key("mod_topic_footer_message")
    end

    it "drops the footer when its feature toggle is off" do
      SiteSetting.topic_footer_message_enabled = false
      sign_in(user)
      get "/t/#{footer_topic.id}.json"
      expect(response.parsed_body).not_to have_key("mod_topic_footer_message")
    end
  end
end
