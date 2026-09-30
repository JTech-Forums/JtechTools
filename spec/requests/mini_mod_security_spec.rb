# frozen_string_literal: true

# What a category group moderator must NOT be able to do through Mini-mod's
# grants: reach categories they can't see, change who can see or moderate a
# category, reorder the site's categories, or edit topics core keeps off
# limits.
RSpec.describe "Mini-mod limits" do
  fab!(:mini_mod) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:mod_group, :group)
  fab!(:private_group, :group)
  fab!(:moderated) { Fabricate(:private_category, group: private_group) }
  fab!(:other, :category)
  fab!(:hidden) { Fabricate(:private_category, group: Fabricate(:group)) }

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    mod_group.add(mini_mod)
    private_group.add(mini_mod)
    Fabricate(:category_moderation_group, category: moderated, group: mod_group)
    sign_in(mini_mod)
  end

  def update(category, params)
    put "/categories/#{category.id}.json",
        params: {
          name: category.name,
          color: category.color,
          text_color: category.text_color,
        }.merge(params)
  end

  describe "categories they moderate" do
    it "saves ordinary settings" do
      update(moderated, description: "New words", slug: "renamed")
      expect(response.status).to eq(200)
      expect(moderated.reload.slug).to eq("renamed")
    end

    it "ignores changes to who can see the category" do
      update(moderated, permissions: { "everyone" => 1 })
      expect(response.status).to eq(200)
      expect(moderated.reload.read_restricted).to eq(true)
      expect(moderated.permissions_params).to eq(private_group.name => 1)
    end

    it "ignores changes to who moderates it" do
      update(moderated, moderating_group_ids: [Group::AUTO_GROUPS[:trust_level_0]])
      expect(response.status).to eq(200)
      expect(moderated.reload.moderating_group_ids).to eq([mod_group.id])
    end

    it "ignores incoming email, custom fields and position" do
      update(moderated, email_in: "leak@example.com", custom_fields: { secret: "x" }, position: 0)
      expect(response.status).to eq(200)
      moderated.reload
      expect(moderated.email_in).to be_nil
      expect(moderated.custom_fields["secret"]).to be_nil
    end

    it "refuses moving the category under one they don't moderate" do
      update(moderated, parent_category_id: other.id)
      expect(response.status).to eq(403)
      expect(moderated.reload.parent_category_id).to be_nil
    end

    it "never deletes it" do
      delete "/categories/#{moderated.id}.json"
      expect(response.status).to eq(403)
    end
  end

  describe "new subcategories" do
    it "inherit the parent's access and moderators" do
      post "/categories.json",
           params: {
             name: "Sub",
             color: "ff0000",
             text_color: "ffffff",
             parent_category_id: moderated.id,
             permissions: {
               "everyone" => 1,
             },
             moderating_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
           }
      expect(response.status).to eq(200)

      sub = Category.find_by(name: "Sub")
      expect(sub.read_restricted).to eq(true)
      expect(sub.permissions_params).to eq(private_group.name => 1)
      expect(sub.moderating_group_ids).to eq([mod_group.id])
      expect(Guardian.new(mini_mod).can_edit_category?(sub)).to eq(true)
    end
  end

  it "can't reorder the site's categories" do
    post "/categories/reorder.json", params: { mapping: { other.id => 0 }.to_json }
    expect(response.status).to eq(403)
  end

  context "with manage-all" do
    before { SiteSetting.mini_mod_manage_all_categories = true }

    it "still can't touch a category they can't see" do
      update(hidden, permissions: { "everyone" => 1 })
      expect(response.status).to eq(403)
      expect(hidden.reload.read_restricted).to eq(true)
      expect(Guardian.new(mini_mod).can_create_category?(hidden)).to eq(false)
    end

    it "can't move topics into a category they can't see" do
      expect(Guardian.new(mini_mod).can_move_topic_to_category?(hidden)).to eq(false)
    end

    describe "editing topics" do
      before { SiteSetting.mini_mod_can_edit_topics = true }

      let(:guardian) { Guardian.new(mini_mod) }

      it "reaches ordinary topics anywhere they can post" do
        expect(guardian.can_edit_topic?(Fabricate(:topic, category: other))).to eq(true)
      end

      it "stays away from private messages, archived topics and the static pages" do
        pm =
          Fabricate(
            :private_message_topic,
            topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: mini_mod)],
          )
        expect(guardian.can_edit_topic?(pm)).to eq(false)

        expect(guardian.can_edit_topic?(Fabricate(:topic, category: other, archived: true))).to eq(
          false,
        )

        tos = Fabricate(:topic, category: other)
        SiteSetting.tos_topic_id = tos.id
        expect(guardian.can_edit_topic?(tos)).to eq(false)
      end
    end
  end

  describe "tag administration" do
    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.mini_mod_manage_tags = true
    end

    it "keeps the site-wide unused-tag and CSV tools with staff" do
      expect(Guardian.new(mini_mod).can_admin_tags?).to eq(true)

      get "/tags/unused.json"
      expect(response.status).to eq(403)

      delete "/tags/unused.json"
      expect(response.status).to eq(403)
    end
  end
end
