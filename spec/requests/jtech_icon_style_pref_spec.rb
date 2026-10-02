# frozen_string_literal: true

require "rails_helper"

RSpec.describe "JTech theme icon style preference" do
  fab!(:user)

  let(:field) { DiscourseJtechTheme::ICON_STYLE_FIELD }

  def current_user_json
    sign_in(user)
    get "/session/current.json"
    expect(response.status).to eq(200)
    response.parsed_body["current_user"]
  end

  it "defaults to lucide when the user has not chosen" do
    expect(current_user_json["jtech_icon_style"]).to eq("lucide")
  end

  it "reflects a classic choice" do
    user.custom_fields[field] = "classic"
    user.save_custom_fields(true)
    expect(current_user_json["jtech_icon_style"]).to eq("classic")
  end

  it "falls back to lucide for an unknown stored value" do
    user.custom_fields[field] = "neon"
    user.save_custom_fields(true)
    expect(current_user_json["jtech_icon_style"]).to eq("lucide")
  end

  it "persists through a preferences update (registered editable)" do
    sign_in(user)
    put "/u/#{user.username}.json", params: { custom_fields: { field => "classic" } }
    expect(response.status).to eq(200)
    expect(user.reload.custom_fields[field]).to eq("classic")
  end
end
