# frozen_string_literal: true

RSpec.describe "Mini-mod tag management" do
  fab!(:mini_mod) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:category)

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    SiteSetting.mini_mod_enabled = true
    SiteSetting.mini_mod_manage_tags = true
    SiteSetting.enable_category_group_moderation = true
    group.add(mini_mod)
    Fabricate(:category_moderation_group, category: category, group: group)
    sign_in(mini_mod)
  end

  it "shows the create-tags form but not the staff-only tools" do
    visit "/tags"
    expect(page).to have_css(".bulk-create-tags-form")
    expect(page).to have_no_css(".tags-admin-dropdown", visible: :visible)

    find(".bulk-tags-input").fill_in(with: "fresh-tag")
    find(".bulk-create-tags-form .btn-primary").click
    expect(page).to have_css(".bulk-create-results", text: "fresh-tag")
    expect(Tag.where(name: "fresh-tag")).to exist
  end
end
