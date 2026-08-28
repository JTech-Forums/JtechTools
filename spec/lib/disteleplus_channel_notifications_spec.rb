# frozen_string_literal: true

require "rails_helper"

# Enrolment + pinning against a real chat channel. CI loads the chat plugin
# (LOAD_PLUGINS=1); when it is absent — a bare core checkout — the behaviour
# under test cannot exist, so the group skips rather than fakes.
#
# Fabricated records get very large ids in the test database, above the
# integer site-setting ceiling, so the channel id is stubbed on SiteSetting
# rather than assigned.
RSpec.describe DiscourseDisteleplus::ChannelNotifications do
  fab!(:channel, :category_channel)
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:admin)
  fab!(:staged) { Fabricate(:user, staged: true) }

  let(:notifications) { described_class }
  let(:membership_class) { ::Chat::UserChatChannelMembership }

  before do
    skip "chat plugin not loaded" unless defined?(::Chat::UserChatChannelMembership)
    SiteSetting.jtech_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_force_channel_notifications = true
    allow(SiteSetting).to receive(:disteleplus_chat_channel_id).and_return(channel.id)
  end

  def membership_for(user)
    membership_class.find_by(user_id: user.id, chat_channel_id: channel.id)
  end

  def level_of(membership)
    membership.reload
    if membership.respond_to?(:notification_level)
      membership.notification_level.to_s
    else
      membership.desktop_notification_level.to_s
    end
  end

  describe ".active?" do
    it "requires the master switch, the toggle and a channel id" do
      expect(notifications.active?).to eq(true)

      SiteSetting.disteleplus_force_channel_notifications = false
      expect(notifications.active?).to eq(false)

      SiteSetting.disteleplus_force_channel_notifications = true
      allow(SiteSetting).to receive(:disteleplus_chat_channel_id).and_return(0)
      expect(notifications.active?).to eq(false)
    end
  end

  describe ".enforce_user!" do
    it "enrols an eligible user at always" do
      outcome = notifications.enforce_user!(member)
      expect(outcome[:enrolled]).to eq(true)

      membership = membership_for(member)
      expect(membership.following).to eq(true)
      expect(level_of(membership)).to eq("always")
    end

    it "raises an existing lower level back to always and unmutes" do
      notifications.enforce_user!(member)
      membership = membership_for(member)
      if membership.respond_to?(:muted)
        membership_class.where(id: membership.id).update_all(muted: true)
      end
      if membership.respond_to?(:notification_level)
        membership_class.where(id: membership.id).update_all(
          notification_level: membership_class.notification_levels[:never],
        )
      end

      outcome = notifications.enforce_user!(member)
      expect(outcome[:enrolled]).to eq(false)
      expect(outcome[:updated]).to eq(true)
      expect(level_of(membership)).to eq("always")
      expect(membership.reload.muted).to eq(false) if membership.respond_to?(:muted)
    end

    it "turns chat back on for a user who disabled it" do
      member.user_option.update_column(:chat_enabled, false)
      outcome = notifications.enforce_user!(member)
      expect(outcome[:chat_enabled_fixed]).to eq(true)
      expect(member.user_option.reload.chat_enabled).to eq(true)
    end

    it "skips staged users and the bridge bot" do
      expect(notifications.enforce_user!(staged)).to be_nil
      bot = DiscourseDisteleplus.bot_user
      expect(notifications.enforce_user!(bot)).to be_nil
      expect(membership_for(bot)).to be_nil
    end

    it "does nothing while inactive" do
      SiteSetting.disteleplus_force_channel_notifications = false
      expect(notifications.enforce_user!(member)).to be_nil
      expect(membership_for(member)).to be_nil
    end
  end

  describe ".enforce_all!" do
    it "enrols every eligible user and reports counts" do
      report = notifications.enforce_all!
      expect(report.channel_id).to eq(channel.id)
      expect(report.eligible).to be >= 2
      expect(membership_for(member)).to be_present
      expect(membership_for(admin)).to be_present
      expect(membership_for(staged)).to be_nil
      expect(report.push_prompt).to be(true).or be(false)
      expect(report.push_devices).to be >= 0
    end
  end

  describe "membership pin (before_save)" do
    it "snaps a user's own level change straight back to always" do
      notifications.enforce_user!(member)
      membership = membership_for(member)

      if membership.respond_to?(:notification_level=)
        membership.notification_level = :mention
      else
        membership.desktop_notification_level = :mention
      end
      membership.save!
      expect(level_of(membership)).to eq("always")
    end

    it "leaves memberships of other channels alone" do
      other = Fabricate(:category_channel)
      other_membership =
        membership_class.create!(user_id: member.id, chat_channel_id: other.id, following: true)
      skip "legacy membership schema" unless other_membership.respond_to?(:notification_level=)

      other_membership.notification_level = :never
      other_membership.save!
      expect(other_membership.reload.notification_level.to_s).to eq("never")
    end
  end

  describe ".status_summary" do
    it "counts members at always" do
      notifications.enforce_user!(member)
      expect(notifications.status_summary).to match(%r{on — \d+/\d+ members at always})
    end

    it "says off when the toggle is off" do
      SiteSetting.disteleplus_force_channel_notifications = false
      expect(notifications.status_summary).to eq("off")
    end
  end
end
