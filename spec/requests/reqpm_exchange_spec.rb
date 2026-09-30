# frozen_string_literal: true

require "rails_helper"

RSpec.describe "REQ-PM exchange" do
  fab!(:alice) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:bob) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:carol) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:admin)

  let(:alice_phone) { add_method(alice, "phone", "+1 718 555 0100") }
  let(:alice_email) { add_method(alice, "email", "alice@example.com") }
  let(:bob_whatsapp) { add_method(bob, "whatsapp", "+972 52 000 1111") }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.reqpm_enabled = true
  end

  def add_method(user, kind, value)
    method = DiscourseReqpm::ContactMethod.new(user_id: user.id, kind: kind)
    method.value = value
    method.save!
    method
  end

  def relationship(username)
    get "/jtech-reqpm/users/#{username}.json"
    expect(response.status).to eq(200)
    response.parsed_body
  end

  def reqpm_notifications(user)
    Notification
      .where(user_id: user.id, notification_type: Notification.types[:custom])
      .map { |n| JSON.parse(n.data) }
      .select { |d| d["reqpm"] }
  end

  describe "requesting" do
    it "notifies the target without any contact value and shows it in their inbox" do
      alice_phone
      sign_in(bob)
      post "/jtech-reqpm/requests.json",
           params: {
             username: alice.username,
             wanted_kinds: %w[phone bogus],
           }
      expect(response.status).to eq(201)
      expect(response.parsed_body["outgoing_request"]).to include("state" => "waiting")
      expect(response.parsed_body["their_methods"]).to eq([])

      notification = reqpm_notifications(alice).sole
      expect(notification).to include(
        "reqpm_kind" => "request",
        "display_username" => bob.username,
        "url" => "/reqpm?tab=requests",
      )
      expect(notification.to_json).not_to include("555")

      request = DiscourseReqpm::Request.last
      expect(request.wanted_kinds).to eq(["phone"])

      sign_in(alice)
      get "/jtech-reqpm/inbox.json"
      incoming = response.parsed_body["incoming"].sole
      expect(incoming.dig("user", "username")).to eq(bob.username)
      expect(incoming["wanted_kinds"]).to eq(["phone"])
    end

    it "does not ask twice while a request is open, and applies the cooldown after" do
      sign_in(bob)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      expect(response.status).to eq(429)
      expect(response.parsed_body.dig("extras", "reason")).to eq("pending")

      DiscourseReqpm::Request.last.update!(status: :declined)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      expect(response.status).to eq(429)
      expect(response.parsed_body.dig("extras", "reason")).to eq("cooldown")
      expect(response.parsed_body.dig("extras", "retry_at")).to be_present

      freeze_time((SiteSetting.reqpm_request_cooldown_days + 1).days.from_now)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      expect(response.status).to eq(201)
    end

    it "respects the daily limit" do
      RateLimiter.enable
      SiteSetting.reqpm_max_requests_per_day = 1
      sign_in(bob)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      expect(response.status).to eq(201)
      post "/jtech-reqpm/requests.json", params: { username: carol.username }
      expect(response.status).to eq(429)
    ensure
      RateLimiter.disable
    end

    it "cannot reach someone who ignores or mutes you, or who turned requests off" do
      Fabricate(:ignored_user, user: alice, ignored_user: bob, expiring_at: 1.month.from_now)
      Fabricate(:muted_user, user: carol, muted_user: bob)
      sign_in(bob)

      [alice, carol].each do |target|
        post "/jtech-reqpm/requests.json", params: { username: target.username }
        expect(response.status).to eq(422)
        expect(response.parsed_body.dig("extras", "reason")).to eq("unavailable")
      end

      admin.custom_fields[DiscourseReqpm::ALLOW_REQUESTS_FIELD] = false
      admin.save_custom_fields(true)
      post "/jtech-reqpm/requests.json", params: { username: admin.username }
      expect(response.parsed_body.dig("extras", "reason")).to eq("unavailable")
      expect(
        reqpm_notifications(alice) + reqpm_notifications(carol) + reqpm_notifications(admin),
      ).to be_empty
    end

    it "gives staff no way around someone's choices" do
      Fabricate(:ignored_user, user: alice, ignored_user: admin, expiring_at: 1.month.from_now)
      sign_in(admin)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      expect(response.parsed_body.dig("extras", "reason")).to eq("unavailable")
    end

    it "cannot request yourself, staged users or system accounts" do
      staged = Fabricate(:staged)
      sign_in(bob)
      post "/jtech-reqpm/requests.json", params: { username: bob.username }
      expect(response.parsed_body.dig("extras", "reason")).to eq("self")
      post "/jtech-reqpm/requests.json", params: { username: staged.username }
      expect(response.parsed_body.dig("extras", "reason")).to eq("unavailable")
      post "/jtech-reqpm/requests.json", params: { username: Discourse.system_user.username }
      expect(response.status).to eq(404)
    end

    it "lets the target decline silently — the requester only ever sees 'waiting'" do
      sign_in(bob)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      request = DiscourseReqpm::Request.last

      sign_in(alice)
      post "/jtech-reqpm/requests/#{request.id}/decline.json"
      expect(response.status).to eq(200)
      expect(request.reload).to be_declined
      expect(Notification.where(user_id: alice.id, read: false).count).to eq(0)
      expect(reqpm_notifications(bob)).to be_empty

      sign_in(bob)
      expect(relationship(alice.username).dig("outgoing_request", "state")).to eq("waiting")
      get "/jtech-reqpm/inbox.json"
      expect(response.parsed_body["outgoing"].sole["state"]).to eq("waiting")
    end

    it "lets the requester withdraw, removing the target's notification" do
      sign_in(bob)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      request = DiscourseReqpm::Request.last
      expect(reqpm_notifications(alice).size).to eq(1)

      delete "/jtech-reqpm/requests/#{request.id}.json"
      expect(response.status).to eq(200)
      expect(reqpm_notifications(alice)).to be_empty

      sign_in(carol)
      delete "/jtech-reqpm/requests/#{request.id}.json"
      expect(response.status).to eq(404)
    end

    it "treats a request past its expiry as closed" do
      sign_in(bob)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      freeze_time((SiteSetting.reqpm_request_expiry_days + 1).days.from_now)

      sign_in(alice)
      get "/jtech-reqpm/inbox.json"
      expect(response.parsed_body["incoming"]).to eq([])

      Jobs::ReqpmExpireRequests.new.execute({})
      expect(DiscourseReqpm::Request.last).to be_expired
    end
  end

  describe "sharing" do
    it "shares exactly the chosen methods and nothing else" do
      alice_phone
      alice_email
      sign_in(alice)
      post "/jtech-reqpm/shares.json",
           params: {
             username: bob.username,
             method_ids: [alice_phone.id],
           }
      expect(response.status).to eq(200)
      expect(response.parsed_body["my_shared_method_ids"]).to eq([alice_phone.id])

      notification = reqpm_notifications(bob).sole
      expect(notification).to include(
        "reqpm_kind" => "shared",
        "display_username" => alice.username,
      )
      expect(notification.to_json).not_to include("555")

      sign_in(bob)
      their = relationship(alice.username)["their_methods"]
      expect(their.map { |m| m["value"] }).to eq(["+1 718 555 0100"])
      expect(response.body).not_to include("alice@example.com")

      get "/jtech-reqpm/inbox.json"
      expect(response.body).to include("+1 718 555 0100")
      expect(response.body).not_to include("alice@example.com")

      # Carol, who got nothing, sees nothing.
      sign_in(carol)
      expect(relationship(alice.username)["their_methods"]).to eq([])
      get "/jtech-reqpm/inbox.json"
      expect(response.body).not_to include("555")
    end

    it "answers an open request and marks its notification read" do
      alice_phone
      sign_in(bob)
      post "/jtech-reqpm/requests.json", params: { username: alice.username }
      request = DiscourseReqpm::Request.last

      sign_in(alice)
      post "/jtech-reqpm/shares.json",
           params: {
             username: bob.username,
             method_ids: [alice_phone.id],
           }
      expect(request.reload).to be_fulfilled
      expect(Notification.where(user_id: alice.id, read: false).count).to eq(0)

      sign_in(bob)
      expect(relationship(alice.username).dig("outgoing_request", "state")).to eq("answered")
    end

    it "re-sending with fewer methods takes the rest back, without a new notification" do
      alice_phone
      alice_email
      sign_in(alice)
      post "/jtech-reqpm/shares.json",
           params: {
             username: bob.username,
             method_ids: [alice_phone.id, alice_email.id],
           }
      Notification.where(user_id: bob.id).update_all(read: true)

      post "/jtech-reqpm/shares.json",
           params: {
             username: bob.username,
             method_ids: [alice_email.id],
           }
      expect(DiscourseReqpm::Share.where(recipient_id: bob.id).pluck(:contact_method_id)).to eq(
        [alice_email.id],
      )
      expect(Notification.where(user_id: bob.id, read: false).count).to eq(0)
    end

    it "cannot share someone else's methods" do
      sign_in(alice)
      post "/jtech-reqpm/shares.json",
           params: {
             username: carol.username,
             method_ids: [bob_whatsapp.id],
           }
      expect(response.status).to eq(422)
      expect(DiscourseReqpm::Share.count).to eq(0)
    end

    it "cannot push details onto someone who ignores you" do
      alice_phone
      Fabricate(:ignored_user, user: bob, ignored_user: alice, expiring_at: 1.month.from_now)
      sign_in(alice)
      post "/jtech-reqpm/shares.json",
           params: {
             username: bob.username,
             method_ids: [alice_phone.id],
           }
      expect(response.parsed_body.dig("extras", "reason")).to eq("unavailable")
      expect(DiscourseReqpm::Share.count).to eq(0)
    end

    it "still allows sharing with someone who turned requests off" do
      alice_phone
      bob.custom_fields[DiscourseReqpm::ALLOW_REQUESTS_FIELD] = false
      bob.save_custom_fields(true)
      sign_in(alice)
      post "/jtech-reqpm/shares.json",
           params: {
             username: bob.username,
             method_ids: [alice_phone.id],
           }
      expect(response.status).to eq(200)
    end

    it "revoking removes access and the unread notification" do
      alice_phone
      sign_in(alice)
      post "/jtech-reqpm/shares.json",
           params: {
             username: bob.username,
             method_ids: [alice_phone.id],
           }
      delete "/jtech-reqpm/shares/#{bob.username}.json"
      expect(response.status).to eq(200)
      expect(reqpm_notifications(bob)).to be_empty

      sign_in(bob)
      expect(relationship(alice.username)["their_methods"]).to eq([])
    end

    it "lets the recipient forget a card" do
      alice_phone
      DiscourseReqpm::Share.create!(
        owner_id: alice.id,
        recipient_id: bob.id,
        contact_method_id: alice_phone.id,
      )
      sign_in(bob)
      delete "/jtech-reqpm/received/#{alice.username}.json"
      expect(response.status).to eq(200)
      expect(DiscourseReqpm::Share.count).to eq(0)
    end

    it "shows updates to a shared method and drops deleted ones" do
      alice_phone
      DiscourseReqpm::Share.create!(
        owner_id: alice.id,
        recipient_id: bob.id,
        contact_method_id: alice_phone.id,
      )

      sign_in(alice)
      put "/jtech-reqpm/card/methods/#{alice_phone.id}.json",
          params: {
            reqpm_contact: {
              value: "+1 718 555 0199",
            },
          }
      sign_in(bob)
      expect(relationship(alice.username)["their_methods"].sole["value"]).to eq("+1 718 555 0199")

      sign_in(alice)
      delete "/jtech-reqpm/card/methods/#{alice_phone.id}.json"
      sign_in(bob)
      expect(relationship(alice.username)["their_methods"]).to eq([])
    end
  end

  describe "what staff can see" do
    it "the admin's own REQ-PM view of a user shows nothing that wasn't shared with the admin" do
      alice_phone
      DiscourseReqpm::Share.create!(
        owner_id: alice.id,
        recipient_id: bob.id,
        contact_method_id: alice_phone.id,
      )
      sign_in(admin)
      expect(relationship(alice.username)["their_methods"]).to eq([])
      get "/jtech-reqpm/inbox.json"
      expect(response.body).not_to include("555")
    end

    it "user JSON, the user card and the current user never carry contact values" do
      alice_phone
      DiscourseReqpm::Share.create!(
        owner_id: alice.id,
        recipient_id: bob.id,
        contact_method_id: alice_phone.id,
      )

      sign_in(bob)
      # New members' profiles are hidden by default; the flag rides along.
      get "/u/#{alice.username}/card.json"
      expect(response.parsed_body.dig("user", "profile_hidden")).to eq(true)
      expect(response.parsed_body.dig("user", "reqpm_available")).to eq(true)

      SiteSetting.hide_new_user_profiles = false
      get "/u/#{alice.username}.json"
      expect(response.body).not_to include("555")
      expect(response.parsed_body.dig("user", "reqpm_available")).to eq(true)
      get "/u/#{alice.username}/card.json"
      expect(response.body).not_to include("555")
      expect(response.parsed_body.dig("user", "reqpm_available")).to eq(true)

      sign_in(alice)
      get "/session/current.json"
      expect(response.body).not_to include("555")
    end
  end

  it "counts open requests for the badge" do
    sign_in(bob)
    post "/jtech-reqpm/requests.json", params: { username: alice.username }
    sign_in(carol)
    post "/jtech-reqpm/requests.json", params: { username: alice.username }

    sign_in(alice)
    get "/session/current.json"
    expect(response.parsed_body.dig("current_user", "reqpm", "incoming_count")).to eq(2)
  end

  it "publishes badge and refresh signals that carry no contact data" do
    alice_phone
    sign_in(bob)
    messages =
      MessageBus.track_publish("/reqpm/state") do
        post "/jtech-reqpm/requests.json", params: { username: alice.username }
      end
    expect(messages.sole.user_ids).to eq([alice.id])
    expect(messages.sole.data).to eq({ incoming_count: 1 })

    sign_in(alice)
    messages =
      MessageBus.track_publish("/reqpm/refresh") do
        post "/jtech-reqpm/shares.json",
             params: {
               username: bob.username,
               method_ids: [alice_phone.id],
             }
      end
    expect(messages.sole.user_ids).to eq([bob.id])
    expect(messages.sole.data.to_json).not_to include("555")
  end
end
