# frozen_string_literal: true

require "rails_helper"

# Covers the simplest category edit shapes — name, colors, description, slug.
# Each save runs as a moderator and asserts the response is not a 500. The
# same save is run as admin as a control: if both fail, the bug isn't ours.
RSpec.describe "Category save — basic fields", type: :request do
  fab!(:moderator)
  fab!(:admin)
  fab!(:category)

  before { SiteSetting.mod_categories_enabled = true }

  def expect_not_500
    expect(response.status).not_to eq(500),
                                  "save crashed (500). body starts: #{response.body[0, 200]}"
  end

  shared_examples "a save that does not crash" do |payload_proc|
    it "completes for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: instance_exec(&payload_proc)
      expect_not_500
    end

    it "completes for an admin (control)" do
      sign_in(admin)
      put "/categories/#{category.id}.json", params: instance_exec(&payload_proc)
      expect_not_500
    end
  end

  describe "rename" do
    include_examples "a save that does not crash",
                     -> {
                       {
                         name: "renamed-#{SecureRandom.hex(4)}",
                         color: category.color,
                         text_color: category.text_color,
                       }
                     }
  end

  describe "color change" do
    include_examples "a save that does not crash",
                     -> {
                       {
                         name: category.name,
                         color: "0088cc",
                         text_color: "ffffff",
                       }
                     }
  end

  describe "description change" do
    include_examples "a save that does not crash",
                     -> {
                       {
                         name: category.name,
                         color: category.color,
                         text_color: category.text_color,
                         description: "Updated description body for this category.",
                       }
                     }
  end

  describe "slug change" do
    include_examples "a save that does not crash",
                     -> {
                       {
                         name: category.name,
                         color: category.color,
                         text_color: category.text_color,
                         slug: "renamed-slug-#{SecureRandom.hex(4)}",
                       }
                     }
  end
end
