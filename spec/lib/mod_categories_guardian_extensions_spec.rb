# frozen_string_literal: true

require "rails_helper"

# Moderator category management is core's moderators_manage_categories; the
# Mod module no longer grants it (it used to, without core's check that the
# moderator can see the category).
RSpec.describe DiscourseModCategories::GuardianExtensions do
  fab!(:moderator)
  fab!(:admin)
  fab!(:category)
  fab!(:admin_only) { Fabricate(:private_category, group: Group[:admins]) }

  before { SiteSetting.mod_categories_enabled = true }

  it "grants moderators nothing for categories on its own" do
    guardian = Guardian.new(moderator)
    expect(guardian.can_create_category?).to eq(false)
    expect(guardian.can_edit_category?(category)).to eq(false)
    expect(guardian.can_delete_category?(category)).to eq(false)
  end

  context "with core's moderators_manage_categories" do
    before { SiteSetting.moderators_manage_categories = true }

    it "lets moderators manage categories they can see" do
      guardian = Guardian.new(moderator)
      expect(guardian.can_create_category?).to eq(true)
      expect(guardian.can_edit_category?(category)).to eq(true)
      expect(guardian.can_delete_category?(category)).to eq(true)
    end

    it "keeps admin-only categories out of their reach" do
      guardian = Guardian.new(moderator)
      expect(guardian.can_edit_category?(admin_only)).to eq(false)
      expect(guardian.can_delete_category?(admin_only)).to eq(false)
      expect(
        guardian.can_edit_serialized_category?(category_id: admin_only.id, read_restricted: true),
      ).to eq(false)
    end
  end

  it "leaves admins alone" do
    expect(Guardian.new(admin).can_edit_category?(admin_only)).to eq(true)
  end

  describe "#can_manage_mod_messages?" do
    it "follows the module switch for moderators" do
      expect(Guardian.new(moderator).can_manage_mod_messages?).to eq(true)
      SiteSetting.mod_categories_enabled = false
      expect(Guardian.new(moderator).can_manage_mod_messages?).to eq(false)
    end

    it "never covers regular users" do
      expect(Guardian.new(Fabricate(:user)).can_manage_mod_messages?).to eq(false)
    end
  end
end
