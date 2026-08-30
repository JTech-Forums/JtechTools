# frozen_string_literal: true

require "rails_helper"

# Enrolment + pinning of native conversation state. No Discourse Chat is
# involved: eligibility comes from disteleplus_allowed_groups and the pinned
# level lives on disteleplus_user_states.
RSpec.describe DiscourseDisteleplus::ChannelNotifications do
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:admin)
  fab!(:staged) { Fabricate(:user, staged: true) }
  fab!(:outsider) { Fabricate(:user, trust_level: TrustLevel[0]) }

  let(:notifications) { described_class }
  let(:states) { DiscourseDisteleplus::UserState }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_force_channel_notifications = true
    SiteSetting.disteleplus_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
  end

  describe ".active?" do
    it "requires the master switch and the toggle, but no Chat channel" do
      expect(notifications.active?).to eq(true)

      SiteSetting.disteleplus_force_channel_notifications = false
      expect(notifications.active?).to eq(false)

      SiteSetting.disteleplus_force_channel_notifications = true
      SiteSetting.disteleplus_enabled = false
      expect(notifications.active?).to eq(false)
    end
  end

  describe ".enforce_user!" do
    it "enrols an eligible user at always" do
      outcome = notifications.enforce_user!(member)
      expect(outcome[:enrolled]).to eq(true)
      expect(states.find_by(user: member)).to be_notification_level_always
    end

    it "re-pins a state that drifted to never" do
      states.create!(user: member, notification_level: :never)
      outcome = notifications.enforce_user!(member)
      expect(outcome[:enrolled]).to eq(false)
      expect(outcome[:updated]).to eq(true)
      expect(states.find_by(user: member)).to be_notification_level_always
    end

    it "reports an existing pinned state as unchanged" do
      states.create!(user: member, notification_level: :always)
      outcome = notifications.enforce_user!(member)
      expect(outcome[:enrolled]).to eq(false)
      expect(outcome[:updated]).to eq(false)
    end

    it "skips users outside the allowed groups and staged users" do
      expect(notifications.enforce_user!(outsider)).to be_nil
      expect(notifications.enforce_user!(staged)).to be_nil
      expect(states.count).to eq(0)
    end

    it "always includes admins" do
      expect(notifications.enforce_user!(admin)[:enrolled]).to eq(true)
    end

    it "does nothing while inactive" do
      SiteSetting.disteleplus_force_channel_notifications = false
      expect(notifications.enforce_user!(member)).to be_nil
    end
  end

  describe ".enforce_all!" do
    it "enrols every eligible user and reports counts" do
      report = notifications.enforce_all!
      expect(report.eligible).to eq(2)
      expect(report.enrolled).to eq(2)
      expect(states.pluck(:user_id)).to contain_exactly(member.id, admin.id)
    end

    it "returns nil while inactive" do
      SiteSetting.disteleplus_enabled = false
      expect(notifications.enforce_all!).to be_nil
    end
  end

  describe ".status_summary" do
    it "describes the native enrolment" do
      notifications.enforce_all!
      expect(notifications.status_summary).to include("2/2 native members at always")
    end

    it "is off while inactive" do
      SiteSetting.disteleplus_force_channel_notifications = false
      expect(notifications.status_summary).to eq("off")
    end
  end

  describe Jobs::DisteleplusEnforceUserNotifications do
    it "enrols the given user" do
      described_class.new.execute(user_id: member.id)
      expect(states.find_by(user: member)).to be_notification_level_always
    end
  end

  describe Jobs::DisteleplusSyncChannelNotifications do
    it "runs the full sync" do
      described_class.new.execute({})
      expect(states.count).to eq(2)
    end
  end
end
