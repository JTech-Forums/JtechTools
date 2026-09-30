# frozen_string_literal: true

require "rails_helper"

RSpec.describe "REQ-PM contact card" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:other) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:admin)

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.reqpm_enabled = true
  end

  def add(kind:, value:, **extra)
    post "/jtech-reqpm/card/methods.json",
         params: {
           reqpm_contact: {
             kind: kind,
             value: value,
             **extra,
           },
         }
  end

  describe "access" do
    it "requires login" do
      get "/jtech-reqpm/card.json"
      expect(response.status).to eq(403)
    end

    it "is not found while the module or the master switch is off" do
      sign_in(user)
      SiteSetting.reqpm_enabled = false
      get "/jtech-reqpm/card.json"
      expect(response.status).to eq(404)

      SiteSetting.reqpm_enabled = true
      SiteSetting.jtech_enabled = false
      get "/jtech-reqpm/card.json"
      expect(response.status).to eq(404)
    end

    it "is refused outside the allowed groups" do
      SiteSetting.reqpm_allowed_groups = Group::AUTO_GROUPS[:trust_level_2].to_s
      sign_in(user)
      get "/jtech-reqpm/card.json"
      expect(response.status).to eq(403)
    end

    it "is refused for silenced users" do
      user.update!(silenced_till: 1.day.from_now)
      sign_in(user)
      get "/jtech-reqpm/card.json"
      expect(response.status).to eq(403)
    end

    it "refuses admin API keys acting as a user" do
      api_key = Fabricate(:api_key, user: admin)
      get "/jtech-reqpm/card.json",
          headers: {
            "Api-Key" => api_key.key,
            "Api-Username" => user.username,
          }
      expect(response.status).to eq(403)
    end

    it "refuses an admin impersonating a user" do
      sign_in(admin)
      post "/admin/impersonate.json", params: { username_or_email: user.username }
      expect(response.status).to eq(200)

      get "/jtech-reqpm/card.json"
      expect(response.status).to eq(403)

      get "/session/current.json"
      expect(response.parsed_body.dig("current_user", "reqpm")).to eq("available" => false)
    end

    it "is never cached" do
      sign_in(user)
      get "/jtech-reqpm/card.json"
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end

  describe "editing" do
    before { sign_in(user) }

    it "adds, lists, updates and removes methods" do
      add(kind: "whatsapp", value: "+972 52 123 4567", note: "evenings")
      expect(response.status).to eq(201)
      id = response.parsed_body.dig("method", "id")

      add(kind: "custom", value: "Ask for Moshe", label: "Front desk", emoji: "wave")
      expect(response.status).to eq(201)

      get "/jtech-reqpm/card.json"
      methods = response.parsed_body["methods"]
      expect(methods.map { |m| m["kind"] }).to eq(%w[whatsapp custom])
      expect(methods.first).to include("value" => "+972 52 123 4567", "note" => "evenings")
      expect(methods.last).to include("label" => "Front desk", "emoji" => "wave")

      put "/jtech-reqpm/card/methods/#{id}.json",
          params: {
            reqpm_contact: {
              share_by_default: false,
            },
          }
      expect(response.status).to eq(200)
      expect(response.parsed_body["method"]).to include(
        "share_by_default" => false,
        "value" => "+972 52 123 4567",
      )

      delete "/jtech-reqpm/card/methods/#{id}.json"
      expect(response.status).to eq(200)
      expect(DiscourseReqpm::ContactMethod.where(user_id: user.id).count).to eq(1)
    end

    it "explains what is wrong with a value" do
      add(kind: "email", value: "not an email")
      expect(response.status).to eq(422)
      expect(response.parsed_body.dig("extras", "field")).to eq("value")
      expect(response.parsed_body["errors"].first).to include("email address")
    end

    it "caps the number of methods" do
      SiteSetting.reqpm_max_methods = 1
      add(kind: "phone", value: "0521234567")
      add(kind: "sms", value: "0521234567")
      expect(response.status).to eq(422)
      expect(response.parsed_body.dig("extras", "reason")).to eq("too_many_methods")
    end

    it "cannot touch someone else's method" do
      method = DiscourseReqpm::ContactMethod.new(user_id: other.id, kind: "email")
      method.value = "other@example.com"
      method.save!

      put "/jtech-reqpm/card/methods/#{method.id}.json",
          params: {
            reqpm_contact: {
              value: "mine@example.com",
            },
          }
      expect(response.status).to eq(404)
      delete "/jtech-reqpm/card/methods/#{method.id}.json"
      expect(response.status).to eq(404)
      expect(method.reload.value).to eq("other@example.com")
    end

    it "reorders" do
      add(kind: "phone", value: "0521234567")
      a = response.parsed_body.dig("method", "id")
      add(kind: "email", value: "a@b.co")
      b = response.parsed_body.dig("method", "id")

      put "/jtech-reqpm/card/methods/order.json", params: { ids: [b, a] }
      expect(response.parsed_body["methods"].map { |m| m["id"] }).to eq([b, a])

      put "/jtech-reqpm/card/methods/order.json", params: { ids: [b] }
      expect(response.status).to eq(422)
    end

    it "turns requests off and on" do
      put "/jtech-reqpm/card/preferences.json", params: { allow_requests: false }
      expect(response.parsed_body["allow_requests"]).to eq(false)
      expect(DiscourseReqpm::Policy.allows_requests?(user.reload)).to eq(false)
    end

    it "keeps contact details out of the request log" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      filtered = filter.filter("reqpm_contact" => { "value" => "+1 555 0100" })
      expect(filtered["reqpm_contact"]).to eq("[FILTERED]")
    end
  end

  describe "setup prompt" do
    def summary
      get "/session/current.json"
      response.parsed_body.dig("current_user", "reqpm")
    end

    before { sign_in(user) }

    it "asks members without a card, gently by default" do
      expect(summary).to include("available" => true, "setup_prompt" => "gentle")
    end

    it "stops once they add something" do
      add(kind: "phone", value: "0521234567")
      expect(summary["setup_prompt"]).to be_nil
    end

    it "can be snoozed and declined in gentle mode" do
      post "/jtech-reqpm/card/setup/snooze.json"
      expect(summary["setup_prompt"]).to be_nil

      freeze_time((SiteSetting.reqpm_setup_snooze_days + 1).days.from_now)
      expect(summary["setup_prompt"]).to eq("gentle")

      post "/jtech-reqpm/card/setup/decline.json"
      expect(summary["setup_prompt"]).to be_nil
    end

    it "cannot be snoozed or declined when required" do
      SiteSetting.reqpm_setup_prompt = "required"
      post "/jtech-reqpm/card/setup/decline.json"
      expect(summary["setup_prompt"]).to eq("required")
    end

    it "is off when the setting says so" do
      SiteSetting.reqpm_setup_prompt = "off"
      expect(summary["setup_prompt"]).to be_nil
    end

    it "is not in the payload at all while disabled" do
      SiteSetting.reqpm_enabled = false
      get "/session/current.json"
      expect(response.parsed_body["current_user"]).not_to have_key("reqpm")
    end
  end

  it "wipes everything when an account is anonymized" do
    method = DiscourseReqpm::ContactMethod.new(user_id: user.id, kind: "email")
    method.value = "gone@example.com"
    method.save!
    DiscourseReqpm::Share.create!(
      owner_id: user.id,
      recipient_id: other.id,
      contact_method_id: method.id,
    )
    DiscourseReqpm::Request.create!(requester_id: other.id, target_id: user.id)

    UserAnonymizer.new(user, Discourse.system_user).make_anonymous

    expect(DiscourseReqpm::ContactMethod.where(user_id: user.id)).to be_empty
    expect(DiscourseReqpm::Share.where(owner_id: user.id)).to be_empty
    expect(DiscourseReqpm::Request.where(target_id: user.id)).to be_empty
  end
end
