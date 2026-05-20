# frozen_string_literal: true

require "rails_helper"

# `POST /categories.json` is its own controller action and can fail
# differently from update. Same probe pattern: never 500 for a moderator.
RSpec.describe "Category create — variants", type: :request do
  fab!(:moderator)
  fab!(:admin)
  fab!(:parent_category, :category)
  fab!(:group)

  before { SiteSetting.mod_categories_enabled = true }

  def expect_not_500
    expect(response.status).not_to eq(500),
                                  "create crashed (500). body starts: #{response.body[0, 200]}"
  end

  describe "minimal top-level category" do
    let(:payload) do
      {
        name: "mod-created-#{SecureRandom.hex(4)}",
        color: "ff0000",
        text_color: "ffffff",
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      post "/categories.json", params: payload
      expect_not_500
    end

    it "does not 500 for an admin (control)" do
      sign_in(admin)
      post "/categories.json", params: payload
      expect_not_500
    end
  end

  describe "subcategory under an existing parent" do
    let(:payload) do
      {
        name: "mod-sub-#{SecureRandom.hex(4)}",
        color: "00ff00",
        text_color: "ffffff",
        parent_category_id: parent_category.id,
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      post "/categories.json", params: payload
      expect_not_500
    end
  end

  describe "create with permissions in the same request" do
    let(:payload) do
      {
        name: "mod-perms-#{SecureRandom.hex(4)}",
        color: "0000ff",
        text_color: "ffffff",
        permissions: {
          group.name => 2,
        },
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      post "/categories.json", params: payload
      expect_not_500
    end
  end

  describe "create with custom_fields in the same request" do
    let(:payload) do
      {
        name: "mod-cf-#{SecureRandom.hex(4)}",
        color: "abcdef",
        text_color: "ffffff",
        custom_fields: {
          "another_plugin_key" => "x",
        },
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      post "/categories.json", params: payload
      expect_not_500
    end
  end

  describe "create with topic settings in the same request" do
    let(:payload) do
      {
        name: "mod-settings-#{SecureRandom.hex(4)}",
        color: "123456",
        text_color: "ffffff",
        auto_close_hours: 48,
        default_view: "latest",
        sort_order: "activity",
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      post "/categories.json", params: payload
      expect_not_500
    end
  end
end
