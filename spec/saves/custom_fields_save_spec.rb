# frozen_string_literal: true

require "rails_helper"

# Custom fields are written through a separate code path
# (CategoryCustomField + bulk_save) and have historically had their own
# permission quirks. Covers add / update / remove shapes.
RSpec.describe "Category save — custom_fields", type: :request do
  fab!(:moderator)
  fab!(:admin)
  fab!(:category)

  before { SiteSetting.mod_categories_enabled = true }

  def expect_not_500
    expect(response.status).not_to eq(500),
                                  "custom_fields save crashed (500). body starts: #{response.body[0, 200]}"
  end

  describe "adding a new custom field" do
    let(:payload) do
      {
        name: category.name,
        color: category.color,
        text_color: category.text_color,
        custom_fields: {
          "my_plugin_key" => "hello",
        },
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end

    it "does not 500 for an admin (control)" do
      sign_in(admin)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end

  describe "updating an existing custom field" do
    before do
      category.custom_fields["my_plugin_key"] = "before"
      category.save_custom_fields
    end

    let(:payload) do
      {
        name: category.name,
        color: category.color,
        text_color: category.text_color,
        custom_fields: {
          "my_plugin_key" => "after",
        },
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end

  describe "clearing a custom field" do
    before do
      category.custom_fields["my_plugin_key"] = "before"
      category.save_custom_fields
    end

    let(:payload) do
      {
        name: category.name,
        color: category.color,
        text_color: category.text_color,
        custom_fields: {
          "my_plugin_key" => "",
        },
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end
end
