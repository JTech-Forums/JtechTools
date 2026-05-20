# frozen_string_literal: true

RSpec.describe "Bulk topic category change for mini-mods" do
  fab!(:user)
  fab!(:group)
  fab!(:source_category) { Fabricate(:category) }
  fab!(:target_category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: source_category).tap { |t| Fabricate(:post, topic: t) } }

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: source_category, group: group)
    Fabricate(:category_moderation_group, category: target_category, group: group)
  end

  it "allows mini-mod to bulk-change topic category to a moderated category" do
    sign_in(user)

    put "/topics/bulk.json",
        params: {
          topic_ids: [topic.id],
          operation: {
            type: "change_category",
            category_id: target_category.id,
          },
        }

    expect(response.status).to eq(200)
    body = response.parsed_body
    expect(body["topic_ids"]).to include(topic.id)
    expect(topic.reload.category_id).to eq(target_category.id)
  end

  it "does not allow moving from an unmoderated category" do
    unmoderated = Fabricate(:category)
    other_topic = Fabricate(:topic, category: unmoderated).tap { |t| Fabricate(:post, topic: t) }
    sign_in(user)

    put "/topics/bulk.json",
        params: {
          topic_ids: [other_topic.id],
          operation: {
            type: "change_category",
            category_id: target_category.id,
          },
        }

    expect(response.status).to eq(200)
    body = response.parsed_body
    expect(body["topic_ids"]).to be_empty
    expect(other_topic.reload.category_id).to eq(unmoderated.id)
  end

  context "with mini_mod_manage_all_categories enabled" do
    before { SiteSetting.mini_mod_manage_all_categories = true }

    it "allows moving topics from an unmoderated category to any category" do
      unmoderated = Fabricate(:category)
      other_topic = Fabricate(:topic, category: unmoderated).tap { |t| Fabricate(:post, topic: t) }
      any_target = Fabricate(:category)
      sign_in(user)

      put "/topics/bulk.json",
          params: {
            topic_ids: [other_topic.id],
            operation: {
              type: "change_category",
              category_id: any_target.id,
            },
          }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["topic_ids"]).to include(other_topic.id)
      expect(other_topic.reload.category_id).to eq(any_target.id)
    end
  end
end
