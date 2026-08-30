# frozen_string_literal: true

require "rails_helper"

# "Quote in chat" mod action: a staff member sends a forum post into the
# native conversation as canonical [quote] markup.
RSpec.describe "Disteleplus quote in chat" do
  fab!(:admin)
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:topic)
  fab!(:quoted) { Fabricate(:post, topic: topic, raw: "the quoted body text") }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
  end

  it "creates a conversation message carrying the [quote] wrapper" do
    sign_in(admin)
    expect { post "/jtech-disteleplus/quote.json", params: { post_id: quoted.id } }.to change {
      DiscourseDisteleplus::Message.count
    }.by(1)
    expect(response.status).to eq(200)

    message = DiscourseDisteleplus::Message.last
    expect(message.raw).to include(
      "[quote=\"#{quoted.user.username}, post:#{quoted.post_number}, topic:#{quoted.topic_id}\"]",
    )
    expect(message.raw).to include("the quoted body text")
    expect(message.raw).to include("[/quote]")
    expect(response.parsed_body["message_id"]).to eq(message.id)
  end

  it "refuses non-staff" do
    sign_in(member)
    post "/jtech-disteleplus/quote.json", params: { post_id: quoted.id }
    expect(response.status).to eq(403)
  end

  it "404s on a missing post" do
    sign_in(admin)
    post "/jtech-disteleplus/quote.json", params: { post_id: 0 }
    expect(response.status).to eq(404)
  end

  it "refuses posts the actor cannot see" do
    group = Fabricate(:group)
    category = Fabricate(:private_category, group: group)
    hidden = Fabricate(:post, topic: Fabricate(:topic, category: category))
    moderator = Fabricate(:moderator)
    sign_in(moderator)
    post "/jtech-disteleplus/quote.json", params: { post_id: hidden.id }
    expect(response.status).to eq(404).or(eq(403))
  end

  it "404s when the module is disabled" do
    SiteSetting.disteleplus_enabled = false
    sign_in(admin)
    post "/jtech-disteleplus/quote.json", params: { post_id: quoted.id }
    expect(response.status).to eq(404)
  end
end
