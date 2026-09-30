# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dumbcourse endpoints" do
  fab!(:user)

  before { SiteSetting.dumbcourse_enabled = true }

  describe "POST /dumb/api/preview" do
    it "cooks the draft the way the post will look" do
      sign_in(user)
      post "/dumb/api/preview.json", params: { raw: "**bold** :smile: <script>alert(1)</script>" }
      expect(response.status).to eq(200)
      cooked = response.parsed_body["cooked"]
      expect(cooked).to include("<strong>bold</strong>")
      expect(cooked).to include("emoji")
      expect(cooked).not_to include("<script>")
    end

    it "needs a signed-in member" do
      post "/dumb/api/preview.json", params: { raw: "hi" }
      expect(response.status).to eq(403)
    end

    it "refuses drafts over the post length limit" do
      sign_in(user)
      post "/dumb/api/preview.json", params: { raw: "a" * (SiteSetting.max_post_length + 1) }
      expect(response.status).to eq(400)
    end

    it "is rate limited" do
      RateLimiter.enable
      sign_in(user)
      30.times { post "/dumb/api/preview.json", params: { raw: "hi" } }
      post "/dumb/api/preview.json", params: { raw: "hi" }
      expect(response.status).to eq(429)
    end
  end

  describe "POST /dumb/languagetool/check" do
    before do
      SiteSetting.dumbcourse_languagetool_enabled = true
      SiteSetting.dumbcourse_languagetool_url = "https://lt.example.com"
    end

    it "refuses very long texts before calling out" do
      sign_in(user)
      post "/dumb/languagetool/check.json", params: { text: "a" * 20_001 }
      expect(response.status).to eq(413)
    end

    it "is rate limited per member" do
      RateLimiter.enable
      stub_request(:post, "https://lt.example.com/v2/check").to_return(
        status: 200,
        body: { matches: [] }.to_json,
      )
      sign_in(user)
      30.times { post "/dumb/languagetool/check.json", params: { text: "teh" } }
      post "/dumb/languagetool/check.json", params: { text: "teh" }
      expect(response.status).to eq(429)
    end
  end

  describe "POST /dumb/push/register" do
    before { SiteSetting.dumbcourse_push_enabled = true }

    it "only accepts well-formed topics and device ids" do
      sign_in(user)
      post "/dumb/push/register.json", params: { topic: "x y\nz", device_id: "abc" }
      expect(response.status).to eq(400)

      post "/dumb/push/register.json",
           params: {
             topic: "dumbcourse-abcd1234-xyz",
             device_id: "dev-1",
           }
      expect(response.status).to eq(200)
    end
  end
end
