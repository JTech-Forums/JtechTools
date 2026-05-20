# frozen_string_literal: true

# End-to-end coverage for the category-management features. Hits the actual
# /categories.json endpoints as a mini-mod and verifies the plugin's Guardian
# overrides correctly grant create/edit/delete permissions on moderated
# categories (and deny them on unmoderated ones, unless mini_mod_manage_all_categories
# is on).
RSpec.describe "Category management for mini-mods" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:moderated_category, :category)
  fab!(:other_category, :category)

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: moderated_category, group: group)
  end

  describe "POST /categories.json" do
    before { sign_in(user) }

    it "lets a mini-mod create a top-level category" do
      expect {
        post "/categories.json",
             params: {
               name: "minimod-created-top-level",
               color: "ff0000",
               text_color: "ffffff",
             }
      }.to change { Category.count }.by(1)
      expect(response.status).to eq(200)
    end

    it "lets a mini-mod create a subcategory under a moderated category" do
      expect {
        post "/categories.json",
             params: {
               name: "minimod-subcategory",
               color: "00ff00",
               text_color: "ffffff",
               parent_category_id: moderated_category.id,
             }
      }.to change { Category.count }.by(1)
      expect(response.status).to eq(200)
      expect(Category.last.parent_category_id).to eq(moderated_category.id)
    end

    it "blocks a mini-mod from creating a subcategory under an unmoderated category" do
      expect {
        post "/categories.json",
             params: {
               name: "should-not-exist",
               color: "0000ff",
               text_color: "ffffff",
               parent_category_id: other_category.id,
             }
      }.not_to change { Category.count }
      expect(response.status).to eq(403)
    end

    context "with mini_mod_manage_all_categories enabled" do
      before { SiteSetting.mini_mod_manage_all_categories = true }

      it "lets the mini-mod create a subcategory under any category" do
        expect {
          post "/categories.json",
               params: {
                 name: "manage-all-subcategory",
                 color: "abcdef",
                 text_color: "ffffff",
                 parent_category_id: other_category.id,
               }
        }.to change { Category.count }.by(1)
        expect(response.status).to eq(200)
      end
    end
  end

  describe "PUT /categories/:id.json" do
    before { sign_in(user) }

    it "lets a mini-mod edit a category they moderate" do
      put "/categories/#{moderated_category.id}.json",
          params: {
            name: "renamed-by-minimod",
            color: moderated_category.color,
            text_color: moderated_category.text_color,
          }
      expect(response.status).to eq(200)
      expect(moderated_category.reload.name).to eq("renamed-by-minimod")
    end

    it "blocks a mini-mod from editing a category they do not moderate" do
      original_name = other_category.name
      put "/categories/#{other_category.id}.json",
          params: {
            name: "should-not-rename",
            color: other_category.color,
            text_color: other_category.text_color,
          }
      expect(response.status).to eq(403)
      expect(other_category.reload.name).to eq(original_name)
    end

    context "with mini_mod_manage_all_categories enabled" do
      before { SiteSetting.mini_mod_manage_all_categories = true }

      it "lets the mini-mod edit any category" do
        put "/categories/#{other_category.id}.json",
            params: {
              name: "manage-all-renamed",
              color: other_category.color,
              text_color: other_category.text_color,
            }
        expect(response.status).to eq(200)
        expect(other_category.reload.name).to eq("manage-all-renamed")
      end
    end
  end

  describe "DELETE /categories/:id.json" do
    before { sign_in(user) }

    it "lets a mini-mod delete an empty moderated category" do
      empty_moderated = Fabricate(:category)
      Fabricate(:category_moderation_group, category: empty_moderated, group: group)
      expect { delete "/categories/#{empty_moderated.id}.json" }.to change {
        Category.where(id: empty_moderated.id).count
      }.from(1).to(0)
      expect(response.status).to eq(200)
    end

    it "blocks a mini-mod from deleting an unmoderated category" do
      delete "/categories/#{other_category.id}.json"
      expect(response.status).to eq(403)
      expect(Category.where(id: other_category.id)).to exist
    end
  end
end
