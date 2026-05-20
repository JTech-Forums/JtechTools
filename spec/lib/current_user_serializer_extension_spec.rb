# frozen_string_literal: true

# Verifies the plugin's add_to_serializer hook on CurrentUserSerializer:
# the can_admin_tags field should appear (and reflect the user's permissions)
# only when mini_mod_manage_tags + tagging are enabled and the user is a CGM.
RSpec.describe CurrentUserSerializer do
  fab!(:user)
  fab!(:group)
  fab!(:category)

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: category, group: group)
  end

  def serialized(viewer)
    CurrentUserSerializer.new(viewer, scope: Guardian.new(viewer), root: false).as_json
  end

  context "when mini_mod_manage_tags + tagging are enabled" do
    before do
      SiteSetting.mini_mod_manage_tags = true
      SiteSetting.tagging_enabled = true
    end

    it "exposes can_admin_tags = true for a mini-mod" do
      expect(serialized(user)[:can_admin_tags]).to eq(true)
    end

    it "still exposes can_admin_tags for an admin" do
      expect(serialized(Fabricate(:admin))[:can_admin_tags]).to eq(true)
    end
  end

  context "when mini_mod_manage_tags is disabled" do
    before do
      SiteSetting.mini_mod_manage_tags = false
      SiteSetting.tagging_enabled = true
    end

    it "omits can_admin_tags from the serializer" do
      expect(serialized(user)).not_to have_key(:can_admin_tags)
    end
  end

  context "when tagging is disabled" do
    before do
      SiteSetting.mini_mod_manage_tags = true
      SiteSetting.tagging_enabled = false
    end

    it "omits can_admin_tags from the serializer" do
      expect(serialized(user)).not_to have_key(:can_admin_tags)
    end
  end

  context "when the plugin is disabled" do
    before do
      SiteSetting.mini_mod_enabled = false
      SiteSetting.mini_mod_manage_tags = true
      SiteSetting.tagging_enabled = true
    end

    it "omits can_admin_tags from the serializer" do
      expect(serialized(user)).not_to have_key(:can_admin_tags)
    end
  end
end
