# frozen_string_literal: true

RSpec.describe DiscourseMiniMod::TopicViewDetailsSerializerExtension do
  fab!(:user)
  fab!(:group)
  fab!(:category)
  fab!(:closed_topic) { Fabricate(:topic, category: category, closed: true) }
  fab!(:open_topic) { Fabricate(:topic, category: category) }

  before do
    SiteSetting.mini_mod_enabled = true
    SiteSetting.enable_category_group_moderation = true
    group.add(user)
    Fabricate(:category_moderation_group, category: category, group: group)
  end

  def can_close_topic_field(topic, viewer)
    TopicViewDetailsSerializer
      .new(TopicView.new(topic, viewer), scope: Guardian.new(viewer))
      .as_json
      .dig(:topic_view_details, :can_close_topic)
  end

  it "omits can_close_topic for mini-mods on closed topics by default" do
    expect(can_close_topic_field(closed_topic, user)).to eq(nil)
  end

  it "still includes can_close_topic for mini-mods on open topics" do
    expect(can_close_topic_field(open_topic, user)).to eq(true)
  end

  it "does not affect site moderators on closed topics" do
    expect(can_close_topic_field(closed_topic, Fabricate(:moderator))).to eq(true)
  end

  it "does not affect admins on closed topics" do
    expect(can_close_topic_field(closed_topic, Fabricate(:admin))).to eq(true)
  end

  it "is a no-op when the plugin is disabled" do
    SiteSetting.mini_mod_enabled = false
    expect(can_close_topic_field(closed_topic, user)).to eq(true)
  end

  context "when mini_mod_can_reopen_topics is enabled" do
    before { SiteSetting.mini_mod_can_reopen_topics = true }

    it "includes can_close_topic for mini-mods on closed topics" do
      expect(can_close_topic_field(closed_topic, user)).to eq(true)
    end
  end

  # Mirrors the Guardian-level tl4_can_reopen_topics restriction. Without this
  # branch in the serializer, the topic admin menu still rendered the
  # close/reopen toggle for trust level 4 users on closed topics, and clicking
  # it surfaced a 403 from ensure_can_close_topic!.
  describe "TL4 reopen button visibility" do
    fab!(:tl4_user, :trust_level_4)
    fab!(:other_category, :category)
    fab!(:closed_in_other_category) { Fabricate(:topic, category: other_category, closed: true) }
    fab!(:open_in_other_category) { Fabricate(:topic, category: other_category) }

    it "omits can_close_topic for TL4 users on closed topics in mini-mod categories by default" do
      expect(can_close_topic_field(closed_topic, tl4_user)).to eq(nil)
    end

    it "omits can_close_topic for TL4 users on closed topics in any category by default" do
      expect(can_close_topic_field(closed_in_other_category, tl4_user)).to eq(nil)
    end

    it "still includes can_close_topic for TL4 users on open topics in mini-mod categories" do
      expect(can_close_topic_field(open_topic, tl4_user)).to eq(true)
    end

    it "still includes can_close_topic for TL4 users on open topics in any category" do
      expect(can_close_topic_field(open_in_other_category, tl4_user)).to eq(true)
    end

    it "does not affect site moderators on closed topics" do
      expect(can_close_topic_field(closed_in_other_category, Fabricate(:moderator))).to eq(true)
    end

    it "does not affect admins on closed topics" do
      expect(can_close_topic_field(closed_in_other_category, Fabricate(:admin))).to eq(true)
    end

    it "is a no-op when the plugin is disabled" do
      SiteSetting.mini_mod_enabled = false
      expect(can_close_topic_field(closed_in_other_category, tl4_user)).to eq(true)
    end

    context "when tl4_can_reopen_topics is enabled" do
      before { SiteSetting.tl4_can_reopen_topics = true }

      it "includes can_close_topic for TL4 users on closed topics" do
        expect(can_close_topic_field(closed_in_other_category, tl4_user)).to eq(true)
      end
    end

    # A TL4 user who is *also* a mini-mod is gated by both restrictions in the
    # Guardian; the serializer must mirror that to avoid leaving the button
    # visible after only one of the two settings is flipped on.
    describe "TL4 user who is also a mini-mod" do
      fab!(:tl4_mini_mod, :trust_level_4)

      before { group.add(tl4_mini_mod) }

      it "omits can_close_topic on closed topics by default" do
        expect(can_close_topic_field(closed_topic, tl4_mini_mod)).to eq(nil)
      end

      it "still omits can_close_topic when only the mini_mod setting is enabled (TL4 still gated)" do
        SiteSetting.mini_mod_can_reopen_topics = true
        expect(can_close_topic_field(closed_topic, tl4_mini_mod)).to eq(nil)
      end

      it "still omits can_close_topic when only the tl4 setting is enabled (mini-mod still gated)" do
        SiteSetting.tl4_can_reopen_topics = true
        expect(can_close_topic_field(closed_topic, tl4_mini_mod)).to eq(nil)
      end

      it "includes can_close_topic when both settings are enabled" do
        SiteSetting.mini_mod_can_reopen_topics = true
        SiteSetting.tl4_can_reopen_topics = true
        expect(can_close_topic_field(closed_topic, tl4_mini_mod)).to eq(true)
      end
    end
  end
end
