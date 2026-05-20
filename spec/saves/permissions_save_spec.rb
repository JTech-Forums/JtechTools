# frozen_string_literal: true

require "rails_helper"

# Category permissions are the leading suspect for moderator-save 500s.
# Discourse's category permission update path historically branches on
# `is_admin?` rather than `is_staff?` in some bookkeeping steps, so a
# non-admin staff user (a moderator under this plugin) may hit an unhandled
# code path that returns HTML 500.
RSpec.describe "Category save — permissions", type: :request do
  fab!(:moderator)
  fab!(:admin)
  fab!(:category)
  fab!(:group)

  before { SiteSetting.mod_categories_enabled = true }

  def expect_not_500
    expect(response.status).not_to eq(500),
                                  "permissions save crashed (500). body starts: #{response.body[0, 200]}"
  end

  describe "setting permissions to a single group at 'create_post' (level 2)" do
    let(:payload) do
      {
        name: category.name,
        color: category.color,
        text_color: category.text_color,
        permissions: {
          group.name => 2,
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

  describe "opening permissions to everyone (Group::AUTO_GROUPS[:everyone])" do
    let(:payload) do
      {
        name: category.name,
        color: category.color,
        text_color: category.text_color,
        permissions: {
          "everyone" => 1,
        },
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end

  describe "restricting permissions to staff only" do
    let(:payload) do
      {
        name: category.name,
        color: category.color,
        text_color: category.text_color,
        permissions: {
          "staff" => 1,
        },
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end

  describe "wiping all custom permissions (empty hash)" do
    before do
      category.set_permissions(group.id => :full)
      category.save!
    end

    let(:payload) do
      {
        name: category.name,
        color: category.color,
        text_color: category.text_color,
        permissions: {
        },
      }
    end

    it "does not 500 for a moderator" do
      sign_in(moderator)
      put "/categories/#{category.id}.json", params: payload
      expect_not_500
    end
  end

  describe "swapping one group's permission level" do
    before do
      category.set_permissions(group.id => :readonly)
      category.save!
    end

    let(:payload) do
      {
        name: category.name,
        color: category.color,
        text_color: category.text_color,
        permissions: {
          group.name => 3,
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
