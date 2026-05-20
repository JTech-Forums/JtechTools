# frozen_string_literal: true

require "rails_helper"

# Covers the rest of the form fields the wrench-edit form posts: position,
# sort order, search priority, auto-close, default views, etc. None of these
# *should* require admin, but each is a different column-touching path so we
# probe them individually.
RSpec.describe "Category save — settings", type: :request do
  fab!(:moderator)
  fab!(:admin)
  fab!(:category)

  before { SiteSetting.mod_categories_enabled = true }

  def base_payload
    {
      name: category.name,
      color: category.color,
      text_color: category.text_color,
    }
  end

  def expect_not_500
    expect(response.status).not_to eq(500),
                                  "settings save crashed (500). body starts: #{response.body[0, 200]}"
  end

  describe "position change" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: base_payload.merge(position: 3)
      expect_not_500
    end
  end

  describe "sort order + ascending" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json",
          params: base_payload.merge(sort_order: "created", sort_ascending: "true")
      expect_not_500
    end
  end

  describe "search priority" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json",
          params: base_payload.merge(search_priority: Searchable::PRIORITIES[:high])
      expect_not_500
    end
  end

  describe "auto-close hours" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: base_payload.merge(auto_close_hours: 72)
      expect_not_500
    end
  end

  describe "default_view" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: base_payload.merge(default_view: "top")
      expect_not_500
    end
  end

  describe "default_top_period" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: base_payload.merge(default_top_period: "weekly")
      expect_not_500
    end
  end

  describe "topic_featured_link_allowed" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json",
          params: base_payload.merge(topic_featured_link_allowed: "true")
      expect_not_500
    end
  end

  describe "navigate_to_first_post_after_read" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json",
          params: base_payload.merge(navigate_to_first_post_after_read: "true")
      expect_not_500
    end
  end

  describe "show_subcategory_list + num_featured_topics" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json",
          params: base_payload.merge(show_subcategory_list: "true", num_featured_topics: 7)
      expect_not_500
    end
  end

  describe "topic_template" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json",
          params:
            base_payload.merge(
              topic_template: "Hi! Use this template when posting in this category.",
            )
      expect_not_500
    end
  end
end
