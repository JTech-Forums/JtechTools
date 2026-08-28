# frozen_string_literal: true

require "rails_helper"

# The chat lock's server-side half. The point under test: with the lock on,
# creation is refused for admins too — the exempt_admins setting only affects
# hub-page navigation, never creation. Needs the chat plugin for the Guardian
# methods to exist; skips otherwise.
RSpec.describe "Disteleplus chat lock" do
  before do
    skip "chat plugin not loaded" unless defined?(::Chat::Channel)
    SiteSetting.jtech_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_chat_channel_id = channel.id
  end

  fab!(:channel) { Fabricate(:category_channel, threading_enabled: true) }
  fab!(:admin)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }

  describe "DiscourseDisteleplus.creation_locked?" do
    it "is off by default and ignores the admin exemption" do
      expect(DiscourseDisteleplus.creation_locked?).to eq(false)

      SiteSetting.disteleplus_lock_chat_ui = true
      SiteSetting.disteleplus_lock_chat_exempt_admins = true
      expect(DiscourseDisteleplus.creation_locked?).to eq(true)
    end

    it "does not engage without a channel to redirect to" do
      SiteSetting.disteleplus_lock_chat_ui = true
      SiteSetting.disteleplus_chat_channel_id = 0
      expect(DiscourseDisteleplus.creation_locked?).to eq(false)
    end
  end

  describe "DiscourseDisteleplus.hub_locked_for?" do
    before { SiteSetting.disteleplus_lock_chat_ui = true }

    it "exempts admins from the redirect only when the setting says so" do
      SiteSetting.disteleplus_lock_chat_exempt_admins = true
      expect(DiscourseDisteleplus.hub_locked_for?(admin)).to eq(false)
      expect(DiscourseDisteleplus.hub_locked_for?(user)).to eq(true)

      SiteSetting.disteleplus_lock_chat_exempt_admins = false
      expect(DiscourseDisteleplus.hub_locked_for?(admin)).to eq(true)
    end
  end

  describe "Guardian creation methods" do
    let(:methods) do
      %i[can_create_direct_message? can_create_chat_channel?].select do |m|
        Guardian.method_defined?(m)
      end
    end

    it "refuses channel and DM creation for everyone, admins included, while locked" do
      skip "no creation guardian methods in this chat version" if methods.empty?
      SiteSetting.disteleplus_lock_chat_ui = true
      SiteSetting.disteleplus_lock_chat_exempt_admins = true

      methods.each do |m|
        expect(Guardian.new(admin).public_send(m)).to eq(false), m.to_s
        expect(Guardian.new(user).public_send(m)).to eq(false), m.to_s
      end
    end

    it "restores normal behaviour when the lock is off" do
      skip "no creation guardian methods in this chat version" if methods.empty?
      SiteSetting.disteleplus_lock_chat_ui = false
      if methods.include?(:can_create_chat_channel?)
        expect(Guardian.new(admin).can_create_chat_channel?).to eq(true)
      end
    end
  end

  describe "threads" do
    it "reports threading off on every channel while locked" do
      expect(channel.threading_enabled).to eq(true)
      SiteSetting.disteleplus_lock_chat_ui = true
      expect(channel.threading_enabled).to eq(false)
      expect(::Chat::Channel.find(channel.id).threading_enabled).to eq(false)
      SiteSetting.disteleplus_lock_chat_ui = false
      expect(channel.threading_enabled).to eq(true)
    end
  end
end
