# frozen_string_literal: true

require "rails_helper"

# Backend contract for the "Desktop Pop Up Notifications" preference: the
# per-user custom field is editable, off by default, and surfaced on the
# current-user serializer as an effective (default-aware) boolean. This is
# the server side of the additive feature — it changes nothing about how
# core notifications are created or delivered.
RSpec.describe "Desktop pop-up notification preference" do
  fab!(:user)

  let(:field) { DiscoursePopupNotifications::USER_ENABLED_FIELD }

  before do
    SiteSetting.popup_notifications_enabled = true
    SiteSetting.popup_notifications_default_enabled = false
  end

  def current_user_json
    sign_in(user)
    get "/session/current.json"
    expect(response.status).to eq(200)
    response.parsed_body["current_user"]
  end

  it "defaults to the site default (off) when the user has not chosen" do
    expect(current_user_json["jtech_popup_notifications_enabled"]).to eq(false)
  end

  it "follows the site default when that default is on" do
    SiteSetting.popup_notifications_default_enabled = true
    expect(current_user_json["jtech_popup_notifications_enabled"]).to eq(true)
  end

  it "reflects an explicit per-user opt-in" do
    user.custom_fields[field] = true
    user.save_custom_fields(true)
    expect(current_user_json["jtech_popup_notifications_enabled"]).to eq(true)
  end

  it "reflects an explicit per-user opt-out even when the default is on" do
    SiteSetting.popup_notifications_default_enabled = true
    user.custom_fields[field] = false
    user.save_custom_fields(true)
    expect(current_user_json["jtech_popup_notifications_enabled"]).to eq(false)
  end

  it "persists the field through a preferences update (registered editable)" do
    sign_in(user)
    put "/u/#{user.username}.json", params: { custom_fields: { field => true } }
    expect(response.status).to eq(200)
    expect(user.reload.custom_fields[field]).to eq(true)
  end
end
