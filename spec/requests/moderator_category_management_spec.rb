# frozen_string_literal: true

require "rails_helper"

# Moderator category management is core's moderators_manage_categories (the
# Mod module used to grant it itself). Hits the real /categories.json
# endpoints to pin the behavior sites relying on it get.
RSpec.describe "Category management for moderators", type: :request do
  fab!(:moderator)
  fab!(:user)
  fab!(:category)

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.moderators_manage_categories = true
  end

  it "keeps admin-only categories away from moderators" do
    admin_only = Fabricate(:private_category, group: Group[:admins])
    sign_in(moderator)
    put "/categories/#{admin_only.id}.json",
        params: {
          name: admin_only.name,
          color: admin_only.color,
          text_color: admin_only.text_color,
          permissions: {
            "everyone" => 1,
          },
        }
    expect(response.status).to eq(403)
    expect(admin_only.reload.read_restricted).to eq(true)
  end

  describe "POST /categories.json" do
    it "lets a moderator create a top-level category" do
      sign_in(moderator)
      expect {
        post "/categories.json",
             params: {
               name: "moderator-created-top-level",
               color: "ff0000",
               text_color: "ffffff",
             }
      }.to change { Category.count }.by(1)
      expect(response.status).to eq(200)
    end

    it "lets a moderator create a subcategory under any category" do
      sign_in(moderator)
      expect {
        post "/categories.json",
             params: {
               name: "moderator-subcategory",
               color: "00ff00",
               text_color: "ffffff",
               parent_category_id: category.id,
             }
      }.to change { Category.count }.by(1)
      expect(response.status).to eq(200)
      expect(Category.last.parent_category_id).to eq(category.id)
    end

    it "blocks a regular user from creating a category" do
      sign_in(user)
      expect {
        post "/categories.json",
             params: {
               name: "should-not-exist",
               color: "0000ff",
               text_color: "ffffff",
             }
      }.not_to change { Category.count }
      expect(response.status).to eq(403)
    end
  end

  describe "PUT /categories/:id.json" do
    it "lets a moderator edit any category" do
      sign_in(moderator)
      put "/categories/#{category.id}.json",
          params: {
            name: "renamed-by-moderator",
            color: category.color,
            text_color: category.text_color,
          }
      expect(response.status).to eq(200)
      expect(category.reload.name).to eq("renamed-by-moderator")
    end

    it "blocks a regular user from editing a category" do
      sign_in(user)
      original_name = category.name
      put "/categories/#{category.id}.json",
          params: {
            name: "should-not-rename",
            color: category.color,
            text_color: category.text_color,
          }
      expect(response.status).to eq(403)
      expect(category.reload.name).to eq(original_name)
    end
  end

  describe "DELETE /categories/:id.json" do
    it "lets a moderator delete an empty category" do
      sign_in(moderator)
      empty = Fabricate(:category)
      expect { delete "/categories/#{empty.id}.json" }.to change {
        Category.where(id: empty.id).count
      }.from(1).to(0)
      expect(response.status).to eq(200)
    end

    it "blocks a regular user from deleting a category" do
      sign_in(user)
      delete "/categories/#{category.id}.json"
      expect(response.status).to eq(403)
      expect(Category.where(id: category.id)).to exist
    end
  end
end
