# frozen_string_literal: true

require "rails_helper"

# Re-parenting a category goes through a different validation path than a
# simple rename and can fail with reasons like "circular parent" or "would
# leave subcategories behind" — but it should never 500.
RSpec.describe "Category save — parent change", type: :request do
  fab!(:moderator)
  fab!(:admin)
  fab!(:top_level_a, :category)
  fab!(:top_level_b, :category)
  fab!(:subcategory) { Fabricate(:category, parent_category: top_level_a) }

  before { SiteSetting.mod_categories_enabled = true }

  def expect_not_500
    expect(response.status).not_to eq(500),
                                  "parent-change save crashed (500). body starts: #{response.body[0, 200]}"
  end

  describe "reparenting a subcategory under a different top-level" do
    let(:payload) do
      {
        name: subcategory.name,
        color: subcategory.color,
        text_color: subcategory.text_color,
        parent_category_id: top_level_b.id,
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{subcategory.id}.json", params: payload
      expect_not_500
    end

    it "does not 500 for an admin (control)" do
      sign_in(admin)
      put "/categories/#{subcategory.id}.json", params: payload
      expect_not_500
    end
  end

  describe "promoting a subcategory to a top-level category" do
    let(:payload) do
      {
        name: subcategory.name,
        color: subcategory.color,
        text_color: subcategory.text_color,
        parent_category_id: nil,
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{subcategory.id}.json", params: payload
      expect_not_500
    end
  end

  describe "no-op save with parent_category_id unchanged" do
    let(:payload) do
      {
        name: subcategory.name,
        color: subcategory.color,
        text_color: subcategory.text_color,
        parent_category_id: top_level_a.id,
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{subcategory.id}.json", params: payload
      expect_not_500
    end
  end
end
