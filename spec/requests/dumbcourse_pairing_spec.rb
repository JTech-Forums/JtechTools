# frozen_string_literal: true

require "rails_helper"

# "Sign in with another device": the phone shows a code, the owner approves
# it from a signed-in session, and only the phone that asked is signed in.
RSpec.describe "Dumbcourse device pairing" do
  fab!(:user) { Fabricate(:user, username: "owner", active: true) }

  before do
    SiteSetting.dumbcourse_enabled = true
    SiteSetting.dumbcourse_device_pairing_enabled = true
  end

  let(:kaios) { "Mozilla/5.0 (Mobile; Nokia_2780; rv:84.0) Gecko/84.0 Firefox/84.0 KAIOS/3.1" }

  def start_on(device)
    device.post "/dumb/auth/pair.json", headers: { "HTTP_USER_AGENT" => kaios }
    expect(device.response.status).to eq(200)
    device.response.parsed_body["code"]
  end

  it "signs in the phone that asked, and only it" do
    phone = open_session
    code = start_on(phone)
    expect(code).to match(/\A[A-Z2-9]{8}\z/)

    phone.get "/dumb/auth/pair/poll.json"
    expect(phone.response.parsed_body["status"]).to eq("pending")

    sign_in(user)
    get "/dumb/auth/pair/lookup.json", params: { code: code.downcase.insert(4, "-") }
    expect(response.status).to eq(200)
    expect(response.parsed_body["device"]).to eq("KaiOS phone, Firefox 84")

    post "/dumb/auth/pair/approve.json", params: { code: code }
    expect(response.status).to eq(200)

    # Someone who only knows the code gets nothing.
    stranger = open_session
    stranger.get "/dumb/auth/pair/poll.json"
    expect(stranger.response.parsed_body["status"]).to eq("expired")
    stranger.get "/session/current.json"
    expect(stranger.response.status).to eq(404)

    phone.get "/dumb/auth/pair/poll.json"
    expect(phone.response.parsed_body["status"]).to eq("approved")
    phone.get "/session/current.json"
    expect(phone.response.parsed_body.dig("current_user", "username")).to eq("owner")

    # A code works once.
    get "/dumb/auth/pair/lookup.json", params: { code: code }
    expect(response.status).to eq(404)
  end

  it "tells the phone when the owner says no" do
    phone = open_session
    code = start_on(phone)
    sign_in(user)
    post "/dumb/auth/pair/deny.json", params: { code: code }
    expect(response.status).to eq(200)

    phone.get "/dumb/auth/pair/poll.json"
    expect(phone.response.parsed_body["status"]).to eq("denied")
    phone.get "/session/current.json"
    expect(phone.response.status).to eq(404)
  end

  it "does not sign in an account that was suspended in the meantime" do
    phone = open_session
    code = start_on(phone)
    sign_in(user)
    post "/dumb/auth/pair/approve.json", params: { code: code }
    user.update!(suspended_till: 1.day.from_now, suspended_at: Time.zone.now)

    phone.get "/dumb/auth/pair/poll.json"
    expect(phone.response.parsed_body["status"]).to eq("denied")
  end

  it "expires codes" do
    phone = open_session
    code = start_on(phone)
    Discourse.redis.del(DiscourseDumbcourse::Pairing.code_key(code))

    sign_in(user)
    post "/dumb/auth/pair/approve.json", params: { code: code }
    expect(response.status).to eq(404)
    phone.get "/dumb/auth/pair/poll.json"
    expect(phone.response.parsed_body["status"]).to eq("expired")
  end

  it "requires a signed-in owner to look up or approve" do
    phone = open_session
    code = start_on(phone)
    get "/dumb/auth/pair/lookup.json", params: { code: code }
    expect(response.status).to eq(403)
    post "/dumb/auth/pair/approve.json", params: { code: code }
    expect(response.status).to eq(403)
  end

  it "refuses approvals made with an API key" do
    phone = open_session
    code = start_on(phone)
    api_key = Fabricate(:api_key, user: user)
    post "/dumb/auth/pair/approve.json",
         params: {
           code: code,
         },
         headers: {
           "Api-Key" => api_key.key,
           "Api-Username" => user.username,
         }
    expect(response.status).to eq(403)
  end

  it "refuses a signed-in browser asking for a code" do
    sign_in(user)
    post "/dumb/auth/pair.json"
    expect(response.status).to eq(403)
  end

  it "rate limits code lookups" do
    RateLimiter.enable
    sign_in(user)
    10.times do
      get "/dumb/auth/pair/lookup.json", params: { code: "ABCDEFGH" }
      expect(response.status).to eq(404)
    end
    get "/dumb/auth/pair/lookup.json", params: { code: "ABCDEFGH" }
    expect(response.status).to eq(429)
  end

  it "is unavailable when switched off" do
    SiteSetting.dumbcourse_device_pairing_enabled = false
    post "/dumb/auth/pair.json"
    expect(response.status).to eq(404)
  end
end
