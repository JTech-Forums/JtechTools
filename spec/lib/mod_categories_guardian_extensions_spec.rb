# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseModCategories::GuardianExtensions do
  fab!(:moderator)
  fab!(:user)
  fab!(:admin)
  fab!(:category)

  before { SiteSetting.mod_categories_enabled = true }

  describe "#can_create_category?" do
    it "allows moderators to create categories" do
      expect(Guardian.new(moderator).can_create_category?).to eq(true)
    end

    it "allows moderators to create subcategories under any category" do
      expect(Guardian.new(moderator).can_create_category?(category)).to eq(true)
    end

    it "still allows admins" do
      expect(Guardian.new(admin).can_create_category?).to eq(true)
    end

    it "does not allow regular users" do
      expect(Guardian.new(user).can_create_category?).to eq(false)
    end

    it "does not allow anonymous users" do
      expect(Guardian.new.can_create_category?).to eq(false)
    end

    it "does not allow when plugin is disabled" do
      SiteSetting.mod_categories_enabled = false
      expect(Guardian.new(moderator).can_create_category?).to eq(false)
    end
  end

  describe "#can_edit_category?" do
    it "allows moderators to edit categories" do
      expect(Guardian.new(moderator).can_edit_category?(category)).to eq(true)
    end

    it "does not allow regular users" do
      expect(Guardian.new(user).can_edit_category?(category)).to eq(false)
    end

    it "does not allow when plugin is disabled" do
      SiteSetting.mod_categories_enabled = false
      expect(Guardian.new(moderator).can_edit_category?(category)).to eq(false)
    end
  end

  describe "#can_edit_serialized_category?" do
    it "allows moderators" do
      expect(
        Guardian.new(moderator).can_edit_serialized_category?(
          category_id: category.id,
          read_restricted: false,
        ),
      ).to eq(true)
    end

    it "does not allow regular users" do
      expect(
        Guardian.new(user).can_edit_serialized_category?(
          category_id: category.id,
          read_restricted: false,
        ),
      ).to eq(false)
    end

    it "does not allow when plugin is disabled" do
      SiteSetting.mod_categories_enabled = false
      expect(
        Guardian.new(moderator).can_edit_serialized_category?(
          category_id: category.id,
          read_restricted: false,
        ),
      ).to eq(false)
    end
  end

  describe "#can_delete_category?" do
    fab!(:empty_category, :category)

    it "allows moderators to delete an empty category" do
      expect(Guardian.new(moderator).can_delete_category?(empty_category)).to eq(true)
    end

    it "does not allow deleting categories with topics" do
      Fabricate(:topic, category: empty_category)
      empty_category.reload
      expect(Guardian.new(moderator).can_delete_category?(empty_category)).to eq(false)
    end

    it "does not allow deleting categories with subcategories" do
      Fabricate(:category, parent_category: empty_category)
      empty_category.reload
      expect(Guardian.new(moderator).can_delete_category?(empty_category)).to eq(false)
    end

    it "does not allow deleting the uncategorized category" do
      uncategorized = Category.find(SiteSetting.uncategorized_category_id)
      expect(Guardian.new(moderator).can_delete_category?(uncategorized)).to eq(false)
    end

    it "does not allow regular users" do
      expect(Guardian.new(user).can_delete_category?(empty_category)).to eq(false)
    end

    it "does not allow when plugin is disabled" do
      SiteSetting.mod_categories_enabled = false
      expect(Guardian.new(moderator).can_delete_category?(empty_category)).to eq(false)
    end
  end
end
