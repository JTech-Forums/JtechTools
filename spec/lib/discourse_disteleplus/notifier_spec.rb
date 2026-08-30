# frozen_string_literal: true

require "rails_helper"

# Mention notifications: deep-link URL, message preview and avatar in the
# notification data.
RSpec.describe DiscourseDisteleplus::Notifier do
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:mentioned) { Fabricate(:user, trust_level: TrustLevel[1]) }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
  end

  it "deep-links, previews the message, and carries the actor avatar" do
    message =
      DiscourseDisteleplus::MessageService.new(actor: member).create!(
        raw: "ping @#{mentioned.username} about the deploy",
      )

    notification = Notification.where(user_id: mentioned.id).last
    expect(notification).not_to be_nil

    data = JSON.parse(notification.data)
    expect(data["url"]).to eq("/disteleplus#m#{message.id}")
    expect(data["message"]).to include("mentioned you")
    expect(data["message"]).to include("about the deploy")
    expect(data["excerpt"]).to include("about the deploy")
    expect(data["avatar_template"]).to eq(member.avatar_template)
    expect(data["disteleplus"]).to eq(true)
  end

  it "detects span.mention markup from bare PrettyText cooking" do
    cooked = PrettyText.cook("hi @#{mentioned.username}")
    message = DiscourseDisteleplus::Message.new(cooked: cooked)
    expect(described_class.mentioned_user_ids(message)).to include(mentioned.id)
  end
end
