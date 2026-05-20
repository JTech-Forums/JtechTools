# frozen_string_literal: true

require "rails_helper"

# "Require moderator approval on new topics" is a per-category toggle backed
# by CategorySetting#require_topic_approval. Different Discourse versions
# have accepted this through different param shapes (top-level custom_fields,
# nested category_setting attrs, or the Rails nested_attributes form), so we
# probe each shape independently — any of them returning 500 means the save
# chain breaks for our moderator grant on that specific shape.
#
# Note on "except for TL3": that exemption is the SITE setting
# `approve_new_topics_unless_trust_level`, which is admin-only and outside
# this plugin's scope. The category-level approval flag is what a moderator
# would set; the TL exemption is set separately by an admin in /admin/site_settings.
RSpec.describe "Category save — moderator approval on new topics", type: :request do
  fab!(:moderator)
  fab!(:admin)
  fab!(:category)
  fab!(:reviewer_group, :group)

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
                                  "approval save crashed (500). body starts: #{response.body[0, 200]}"
  end

  describe "require_topic_approval via custom_fields (legacy shape)" do
    let(:payload) do
      base_payload.merge(custom_fields: { "require_topic_approval" => true })
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

  describe "require_topic_approval via top-level param" do
    let(:payload) { base_payload.merge(require_topic_approval: true) }

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end

  describe "require_topic_approval via category_setting nested attrs" do
    let(:payload) do
      base_payload.merge(category_setting: { require_topic_approval: true })
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

  describe "require_reply_approval (sibling toggle on the same model)" do
    let(:payload) do
      base_payload.merge(category_setting: { require_reply_approval: true })
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end

  describe "reviewable_by_group_id (which group reviews queued items)" do
    let(:payload) { base_payload.merge(reviewable_by_group_id: reviewer_group.id) }

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

  describe "clearing the reviewable group" do
    before do
      category.update!(reviewable_by_group_id: reviewer_group.id) if category.respond_to?(:reviewable_by_group_id=)
    end

    let(:payload) { base_payload.merge(reviewable_by_group_id: nil) }

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end

  describe "full approval setup in one save (toggle + reviewer group)" do
    let(:payload) do
      base_payload.merge(
        require_topic_approval: true,
        reviewable_by_group_id: reviewer_group.id,
      )
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

  describe "disabling approval after it was previously enabled" do
    before do
      category.custom_fields["require_topic_approval"] = true
      category.save_custom_fields
    end

    let(:payload) do
      base_payload.merge(
        require_topic_approval: false,
        custom_fields: { "require_topic_approval" => false },
      )
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end
end
