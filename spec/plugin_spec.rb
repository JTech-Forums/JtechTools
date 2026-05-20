# frozen_string_literal: true

require "rails_helper"

# Exercises the plugin's wiring in plugin.rb: the Guardian prepend is in place,
# the master switch flips correctly, and core privileges (admin) are unaffected
# regardless of plugin state.
RSpec.describe "DiscourseModCategories plugin.rb" do
  fab!(:moderator)
  fab!(:admin)
  fab!(:user)
  fab!(:category)

  describe "Guardian prepend" do
    it "wires the GuardianExtensions module into Guardian" do
      expect(Guardian.ancestors).to include(DiscourseModCategories::GuardianExtensions)
    end
  end

  describe "master switch (mod_categories_enabled)" do
    context "when disabled (default)" do
      before { SiteSetting.mod_categories_enabled = false }

      it "denies moderators" do
        guardian = Guardian.new(moderator)
        expect(guardian.can_create_category?).to eq(false)
        expect(guardian.can_edit_category?(category)).to eq(false)
        expect(guardian.can_delete_category?(category)).to eq(false)
      end

      it "still allows admins" do
        guardian = Guardian.new(admin)
        expect(guardian.can_create_category?).to eq(true)
        expect(guardian.can_edit_category?(category)).to eq(true)
      end

      it "still denies regular users" do
        guardian = Guardian.new(user)
        expect(guardian.can_create_category?).to eq(false)
        expect(guardian.can_edit_category?(category)).to eq(false)
        expect(guardian.can_delete_category?(category)).to eq(false)
      end
    end

    context "when enabled" do
      before { SiteSetting.mod_categories_enabled = true }

      it "grants moderators category create/edit/delete" do
        empty_category = Fabricate(:category)
        guardian = Guardian.new(moderator)
        expect(guardian.can_create_category?).to eq(true)
        expect(guardian.can_edit_category?(empty_category)).to eq(true)
        expect(guardian.can_delete_category?(empty_category)).to eq(true)
      end

      it "still denies regular users" do
        guardian = Guardian.new(user)
        expect(guardian.can_create_category?).to eq(false)
        expect(guardian.can_edit_category?(category)).to eq(false)
        expect(guardian.can_delete_category?(category)).to eq(false)
      end

      it "does not change admin privileges" do
        guardian = Guardian.new(admin)
        expect(guardian.can_create_category?).to eq(true)
        expect(guardian.can_edit_category?(category)).to eq(true)
      end
    end
  end

  describe "settings registration" do
    it "registers mod_categories_enabled with the correct default" do
      expect(SiteSetting.defaults[:mod_categories_enabled]).to eq(false)
    end

    it "registers precheck_new_topic_enabled defaulting to true" do
      expect(SiteSetting.defaults[:precheck_new_topic_enabled]).to eq(true)
    end

    it "registers topic_footer_message_enabled defaulting to true" do
      expect(SiteSetting.defaults[:topic_footer_message_enabled]).to eq(true)
    end

    it "registers topic_reply_prompt_enabled defaulting to true" do
      expect(SiteSetting.defaults[:topic_reply_prompt_enabled]).to eq(true)
    end

    it "exposes the feature toggles to the client" do
      client_settings = SiteSetting.client_settings
      expect(client_settings).to include(:precheck_new_topic_enabled)
      expect(client_settings).to include(:topic_footer_message_enabled)
      expect(client_settings).to include(:topic_reply_prompt_enabled)
    end
  end

  describe "moderator-messages Guardian" do
    before { SiteSetting.mod_categories_enabled = true }

    it "lets moderators manage the moderator messages" do
      expect(Guardian.new(moderator).can_manage_mod_messages?).to eq(true)
    end

    it "lets admins manage the moderator messages" do
      expect(Guardian.new(admin).can_manage_mod_messages?).to eq(true)
    end

    it "does not let regular users manage the moderator messages" do
      expect(Guardian.new(user).can_manage_mod_messages?).to eq(false)
    end

    it "does not let anonymous users manage the moderator messages" do
      expect(Guardian.new(nil).can_manage_mod_messages?).to eq(false)
    end

    it "denies moderators when the plugin master switch is off" do
      SiteSetting.mod_categories_enabled = false
      expect(Guardian.new(moderator).can_manage_mod_messages?).to eq(false)
    end
  end
end
