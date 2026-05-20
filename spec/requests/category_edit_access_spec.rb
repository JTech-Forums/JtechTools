# frozen_string_literal: true

RSpec.describe "Category edit access for mini-mods" do
  fab!(:user)
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:group)
  fab!(:category)

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: category, group: group)
    EmberCli.stubs(:script_chunks).returns({ "chunk.admin" => ["chunk.admin.test"] })
  end

  describe "admin bundle preloading" do
    it "injects admin preload links for category group moderators" do
      sign_in(user)
      get "/categories.json"

      html =
        DiscoursePluginRegistry.build_html("server:before-head-close", @controller)
      expect(html).to include('data-discourse-entrypoint="admin"')
    end

    it "does not inject admin preload links for regular users" do
      sign_in(Fabricate(:user))
      get "/categories.json"

      html =
        DiscoursePluginRegistry.build_html("server:before-head-close", @controller)
      expect(html).not_to include('data-discourse-entrypoint="admin"')
    end

    it "does not inject for anonymous users" do
      get "/categories.json"

      html =
        DiscoursePluginRegistry.build_html("server:before-head-close", @controller)
      expect(html).not_to include('data-discourse-entrypoint="admin"')
    end

    it "skips injection for staff users" do
      sign_in(moderator)
      get "/categories.json"

      html =
        DiscoursePluginRegistry.build_html("server:before-head-close", @controller)
      expect(html).not_to include('data-discourse-entrypoint="admin"')
    end

    it "does not inject when plugin is disabled" do
      SiteSetting.mini_mod_enabled = false
      sign_in(user)
      get "/categories.json"

      html =
        DiscoursePluginRegistry.build_html("server:before-head-close", @controller)
      expect(html).not_to include('data-discourse-entrypoint="admin"')
    end

    it "does not inject when category group moderation is disabled" do
      SiteSetting.enable_category_group_moderation = false
      sign_in(user)
      get "/categories.json"

      html =
        DiscoursePluginRegistry.build_html("server:before-head-close", @controller)
      expect(html).not_to include('data-discourse-entrypoint="admin"')
    end

    it "does not inject for users not in any category moderation group" do
      non_mod_user = Fabricate(:user)
      other_group = Fabricate(:group)
      other_group.add(non_mod_user)
      sign_in(non_mod_user)
      get "/categories.json"

      html =
        DiscoursePluginRegistry.build_html("server:before-head-close", @controller)
      expect(html).not_to include('data-discourse-entrypoint="admin"')
    end
  end
end
