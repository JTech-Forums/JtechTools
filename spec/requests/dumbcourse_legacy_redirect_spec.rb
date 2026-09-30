# frozen_string_literal: true

require "rails_helper"

# Old phones get the matching Dumbcourse page instead of a full-site page
# that renders as garbage.
RSpec.describe "Dumbcourse redirect for old browsers" do
  fab!(:topic) { Fabricate(:topic, title: "Which flip phone lasts longest?") }
  fab!(:post_record) { Fabricate(:post, topic: topic) }

  let(:kaios) { "Mozilla/5.0 (Mobile; Nokia_2780; rv:84.0) Gecko/84.0 Firefox/84.0 KAIOS/3.1" }
  let(:old_android) do
    "Mozilla/5.0 (Linux; Android 5.1; Kyocera) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.133 Mobile Safari/537.36"
  end
  let(:modern) do
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
  end
  let(:googlebot) do
    "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.96 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
  end

  before do
    SiteSetting.dumbcourse_enabled = true
    SiteSetting.dumbcourse_redirect_legacy_browsers = true
  end

  def visit_as(ua, path, cookie: nil)
    headers = { "HTTP_USER_AGENT" => ua, "HTTP_ACCEPT" => "text/html" }
    headers["HTTP_COOKIE"] = "dumbcourse_prefer=#{cookie}" if cookie
    get path, headers: headers
  end

  it "sends KaiOS and old Android browsers to the same topic in Dumbcourse" do
    visit_as(kaios, "/t/#{topic.slug}/#{topic.id}")
    expect(response).to redirect_to("/dumb/t/#{topic.slug}/#{topic.id}")

    visit_as(old_android, "/t/#{topic.slug}/#{topic.id}/1")
    expect(response).to redirect_to("/dumb/t/#{topic.slug}/#{topic.id}/1")
  end

  it "maps sign-in, email-login and password-reset links" do
    visit_as(kaios, "/session/email-login/abc123DEF")
    expect(response).to redirect_to("/dumb/email-login/abc123DEF")
    visit_as(kaios, "/u/password-reset/tok-123")
    expect(response).to redirect_to("/dumb/password-reset/tok-123")
    visit_as(kaios, "/u/activate-account/0a1b2c3d4e")
    expect(response).to redirect_to("/dumb/activate-account/0a1b2c3d4e")
    visit_as(kaios, "/login")
    expect(response).to redirect_to("/dumb/login")
  end

  it "leaves modern browsers alone" do
    visit_as(modern, "/t/#{topic.slug}/#{topic.id}")
    expect(response.status).to eq(200)
  end

  it "never redirects search engines" do
    visit_as(googlebot, "/t/#{topic.slug}/#{topic.id}")
    expect(response.status).to eq(200)
  end

  it "follows the choice made in Dumbcourse's preferences" do
    visit_as(modern, "/latest", cookie: "1")
    expect(response).to redirect_to("/dumb/latest")

    visit_as(kaios, "/latest", cookie: "0")
    expect(response.status).to eq(200)
  end

  it "only touches page loads" do
    get "/t/#{topic.id}.json", headers: { "HTTP_USER_AGENT" => kaios }
    expect(response.status).to eq(200)
    expect(response.media_type).to eq("application/json")
  end

  it "can be switched off" do
    SiteSetting.dumbcourse_redirect_legacy_browsers = false
    visit_as(kaios, "/latest")
    expect(response.status).to eq(200)
  end

  it "leaves pages Dumbcourse has no screen for alone" do
    visit_as(kaios, "/about")
    expect(response.status).to eq(200)
  end

  describe DiscourseDumbcourse::LegacyRedirect do
    it "recognises browsers that can't run the full site" do
      expect(described_class.legacy_browser?(kaios)).to eq(true)
      expect(described_class.legacy_browser?(old_android)).to eq(true)
      expect(described_class.legacy_browser?("Opera/9.80 (J2ME/MIDP; Opera Mini/9.80)")).to eq(true)
      expect(described_class.legacy_browser?(modern)).to eq(false)
      expect(described_class.legacy_browser?("")).to eq(false)
    end

    it "maps forum paths to Dumbcourse paths" do
      expect(described_class.target_for("/", "")).to eq("/")
      expect(described_class.target_for("/top", "period=weekly")).to eq("/top?period=weekly")
      expect(described_class.target_for("/c/phones/5/l/latest", "")).to eq("/c/phones/5/l/latest")
      expect(described_class.target_for("/u/alice/summary", "")).to eq("/u/alice")
      expect(described_class.target_for("/u/alice/preferences/account", "")).to eq("/preferences")
      expect(described_class.target_for("/my/bookmarks", "")).to eq("/bookmarks")
      expect(described_class.target_for("/search", "q=battery+life")).to eq(
        "/search?q=battery+life",
      )
      expect(described_class.target_for("/reqpm", "tab=contacts")).to eq("/contacts?tab=contacts")
      expect(described_class.target_for("/admin", "")).to be_nil
      expect(described_class.target_for("/session/email-login/../x", "")).to be_nil
    end
  end
end
