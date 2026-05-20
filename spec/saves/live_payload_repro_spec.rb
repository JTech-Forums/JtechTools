# frozen_string_literal: true

require "rails_helper"

# Reproduction of the exact payload that 500'd against forums.jtechforums.org
# on 2026-05-11 when a moderator (with this plugin installed and enabled)
# tried to save the moderation tab on category 5 ("Filtering"). Captured
# verbatim from Edge DevTools and trimmed only of the corrupt Hebrew
# localization entry (which is plausibly a payload-independent cause —
# tested separately at the bottom of this file).
#
# Each `it` block tries one variant of the payload. Whichever one(s) 500
# names the field combination that breaks the save chain for a moderator
# under this plugin.
RSpec.describe "Category save — JTech live-payload reproduction", type: :request do
  fab!(:moderator)
  fab!(:admin)
  fab!(:category)
  fab!(:tl3_group) { Group.find(Group::AUTO_GROUPS[:trust_level_3]) }

  before { SiteSetting.mod_categories_enabled = true }

  def base_payload
    {
      name: category.name,
      slug: category.slug,
      color: "00615a",
      text_color: "FFFFFF",
      permissions: { "everyone" => 1 },
      position: 3,
      allow_badges: true,
      custom_fields: {
        "require_topic_approval" => "t",
      },
      topic_featured_link_allowed: true,
      show_subcategory_list: false,
      num_featured_topics: 3,
      subcategory_list_style: "rows_with_featured_topics",
      default_top_period: "all",
      minimum_required_tags: 0,
      navigate_to_first_post_after_read: false,
      search_priority: 0,
      moderating_group_ids: [],
      reply_posting_review_group_ids: [],
      default_list_filter: "all",
      style_type: "icon",
      icon: "shield-halved",
      locale: "en",
    }
  end

  def expect_not_500(label)
    expect(response.status).not_to eq(500),
                                  "#{label} crashed (500). body starts: #{response.body[0, 400]}"
  end

  describe "minimal — base fields only, no review-mode, no localizations" do
    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: base_payload
      expect_not_500("minimal save")
    end

    it "does not 500 for an admin (control)" do
      sign_in(admin)
      put "/categories/#{category.id}.json", params: base_payload
      expect_not_500("minimal save (admin)")
    end
  end

  describe "the new approval-mode-with-exempt-group fields" do
    let(:payload) do
      base_payload.merge(
        category_setting_attributes: { topic_posting_review_mode: "everyone_except" },
        topic_posting_review_group_ids: [tl3_group.id],
      )
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("approval-mode + exempt-group")
    end

    it "does not 500 for an admin (control)" do
      sign_in(admin)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("approval-mode + exempt-group (admin)")
    end
  end

  describe "topic_posting_review_group_ids on its own (no mode)" do
    let(:payload) { base_payload.merge(topic_posting_review_group_ids: [tl3_group.id]) }

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("review-group-ids only")
    end
  end

  describe "category_setting_attributes mode on its own (no group_ids)" do
    let(:payload) do
      base_payload.merge(
        category_setting_attributes: { topic_posting_review_mode: "everyone_except" },
      )
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("mode without groups")
    end
  end

  describe "the spurious site-settings hash sent in the category payload" do
    let(:payload) do
      base_payload.merge(
        category_type_site_settings: {
          show_filter_by_solved_status: true,
          prioritize_solved_topics_in_search: true,
          show_who_marked_solved: true,
        },
      )
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("nested site-settings hash")
    end
  end

  describe "category_types multi-type save" do
    let(:payload) { base_payload.merge(category_types: %w[discussion support]) }

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("multi category_types")
    end
  end

  describe "category_localizations with a malformed description" do
    let(:payload) do
      base_payload.merge(
        category_localizations: [
          {
            locale: "he",
            name: "filer",
            description:
              " כל נושאי פילטרינג, עזרה ופ.parentElement.insertAdjacentHTML('beforeend', 'קעי');ל投资额建议。打开过滤器是不允许的。",
          },
        ],
      )
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("malformed Hebrew localization description")
    end
  end

  describe "the full live payload all-at-once" do
    let(:payload) do
      base_payload.merge(
        category_setting_attributes: { topic_posting_review_mode: "everyone_except" },
        topic_posting_review_group_ids: [tl3_group.id],
        category_types: %w[discussion support],
        category_type_site_settings: {
          show_filter_by_solved_status: true,
          prioritize_solved_topics_in_search: true,
          show_who_marked_solved: true,
        },
        custom_fields: base_payload[:custom_fields].merge(
          "enable_accepted_answers" => "true",
          "notify_on_staff_accept_solved" => "true",
          "empty_box_on_unsolved" => "false",
          "solved_topics_auto_close_hours" => "48",
        ),
      )
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("full live payload (no localizations)")
    end

    it "does not 500 for an admin (control)" do
      sign_in(admin)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500("full live payload (admin)")
    end
  end
end
