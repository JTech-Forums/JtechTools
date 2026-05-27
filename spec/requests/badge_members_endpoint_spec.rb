# frozen_string_literal: true

require "rails_helper"

# Verifies the /discourse-mod-categories/badge-members/:badge_id endpoint
# used by the PM composer "Add badge group" button to resolve badge → current
# holders' usernames.
RSpec.describe "Badge members endpoint" do
  fab!(:moderator)
  fab!(:user)
  fab!(:other_holder, :user)
  fab!(:non_holder, :user)
  fab!(:badge) { Fabricate(:badge, name: "PMBadge") }

  before do
    SiteSetting.mod_categories_enabled = true
    Group.refresh_automatic_groups!

    BadgeGranter.grant(badge, user)
    BadgeGranter.grant(badge, other_holder)
  end

  it "returns the current holders' usernames" do
    sign_in(moderator)
    get "/discourse-mod-categories/badge-members/#{badge.id}.json"

    expect(response.status).to eq(200)
    body = response.parsed_body
    expect(body["badge"]["id"]).to eq(badge.id)
    expect(body["badge"]["name"]).to eq(badge.display_name)
    expect(body["usernames"]).to match_array([user.username, other_holder.username])
    expect(body["usernames"]).not_to include(non_holder.username)
  end

  it "excludes the requesting user from the returned list" do
    BadgeGranter.grant(badge, moderator)
    sign_in(moderator)
    get "/discourse-mod-categories/badge-members/#{badge.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["usernames"]).not_to include(moderator.username)
  end

  it "404s when the badge does not exist" do
    sign_in(moderator)
    get "/discourse-mod-categories/badge-members/9999999.json"
    expect(response.status).to eq(404)
  end

  it "requires authentication" do
    get "/discourse-mod-categories/badge-members/#{badge.id}.json"
    expect(response.status).to eq(403)
  end
end
