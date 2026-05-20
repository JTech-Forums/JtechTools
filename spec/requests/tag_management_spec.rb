# frozen_string_literal: true

# End-to-end coverage for the tag-management features. Hits the actual
# /tag/:tag_name endpoints as a mini-mod and verifies the plugin's Guardian
# overrides correctly grant rename/delete/synonym permissions when
# mini_mod_manage_tags is on.
RSpec.describe "Tag management for mini-mods" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:category)

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.mini_mod_manage_tags = true
    SiteSetting.tagging_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: category, group: group)
  end

  describe "PUT /tag/:tag_name.json (rename)" do
    fab!(:tag) { Fabricate(:tag, name: "old-name") }

    it "lets a mini-mod rename a tag" do
      sign_in(user)
      put "/tag/#{tag.name}.json", params: { tag: { name: "new-name" } }
      expect(response.status).to eq(200)
      expect(tag.reload.name).to eq("new-name")
    end

    it "blocks a regular user from renaming a tag" do
      sign_in(Fabricate(:user, refresh_auto_groups: true))
      put "/tag/#{tag.name}.json", params: { tag: { name: "should-not-rename" } }
      expect(tag.reload.name).to eq("old-name")
    end

    it "blocks the rename when mini_mod_manage_tags is disabled" do
      SiteSetting.mini_mod_manage_tags = false
      sign_in(user)
      put "/tag/#{tag.name}.json", params: { tag: { name: "should-not-rename" } }
      expect(tag.reload.name).to eq("old-name")
    end
  end

  describe "DELETE /tag/:tag_name.json" do
    fab!(:tag) { Fabricate(:tag, name: "to-delete") }

    it "lets a mini-mod delete a tag" do
      sign_in(user)
      expect { delete "/tag/#{tag.name}.json" }.to change { Tag.where(id: tag.id).count }.from(
        1,
      ).to(0)
      expect(response.status).to eq(200)
    end

    it "blocks a regular user from deleting a tag" do
      sign_in(Fabricate(:user, refresh_auto_groups: true))
      delete "/tag/#{tag.name}.json"
      expect(Tag.where(id: tag.id)).to exist
    end

    it "blocks the delete when mini_mod_manage_tags is disabled" do
      SiteSetting.mini_mod_manage_tags = false
      sign_in(user)
      delete "/tag/#{tag.name}.json"
      expect(Tag.where(id: tag.id)).to exist
    end
  end

  describe "POST /tag/:tag_name/synonyms.json" do
    fab!(:tag) { Fabricate(:tag, name: "primary-tag") }

    it "lets a mini-mod add a synonym to a tag" do
      sign_in(user)
      post "/tag/#{tag.name}/synonyms.json", params: { synonyms: ["new-synonym"] }
      expect(response.status).to eq(200)
      expect(Tag.find_by(name: "new-synonym")&.target_tag_id).to eq(tag.id)
    end

    it "blocks a regular user from adding a synonym" do
      sign_in(Fabricate(:user, refresh_auto_groups: true))
      post "/tag/#{tag.name}/synonyms.json", params: { synonyms: ["should-not-create"] }
      expect(Tag.find_by(name: "should-not-create")).to be_nil
    end
  end
end
