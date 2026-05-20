# frozen_string_literal: true

require "rails_helper"

# Covers the forum-wide first-post checklist: staff read/edit it, users
# acknowledge it, and the current-user serializer only exposes it to a
# not-yet-trusted user who still owes an acknowledgement.
RSpec.describe "First-post checklist" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }

  let(:ns) { DiscourseModCategories::CHECKLIST_STORE_NAMESPACE }
  let(:key) { DiscourseModCategories::CHECKLIST_STORE_KEY }

  before { SiteSetting.mod_categories_enabled = true }

  def serialized(target)
    CurrentUserSerializer.new(target, scope: Guardian.new(target), root: false).as_json
  end

  describe "GET /discourse-mod-categories/checklist" do
    it "returns the current checklist to a moderator" do
      PluginStore.set(
        ns,
        key,
        { "version" => 3, "items" => [{ "label" => "Read the rules", "url" => "" }] },
      )
      sign_in(moderator)

      get "/discourse-mod-categories/checklist.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["version"]).to eq(3)
      expect(response.parsed_body["items"].first["label"]).to eq("Read the rules")
    end

    it "returns an empty checklist when none is set" do
      sign_in(admin)
      get "/discourse-mod-categories/checklist.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["version"]).to eq(0)
      expect(response.parsed_body["items"]).to eq([])
    end

    it "forbids a regular user" do
      sign_in(user)
      get "/discourse-mod-categories/checklist.json"
      expect(response.status).to eq(403)
    end
  end

  describe "PUT /discourse-mod-categories/checklist" do
    it "lets a moderator save the checklist and bumps the version" do
      sign_in(moderator)

      put "/discourse-mod-categories/checklist.json",
          params: {
            items: [
              { label: "Read the guidelines", url: "https://example.com/rules" },
              { label: "Be kind", url: "" },
            ],
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["version"]).to eq(1)
      expect(response.parsed_body["items"].size).to eq(2)

      put "/discourse-mod-categories/checklist.json",
          params: {
            items: [{ label: "One item", url: "" }],
          }
      expect(response.parsed_body["version"]).to eq(2)
    end

    it "drops rows whose label is blank" do
      sign_in(moderator)

      put "/discourse-mod-categories/checklist.json",
          params: {
            items: [
              { label: "Keep me", url: "" },
              { label: "   ", url: "https://example.com" },
              { label: "", url: "" },
            ],
          }

      expect(response.parsed_body["items"].map { |i| i["label"] }).to eq(["Keep me"])
    end

    it "forbids a regular user" do
      sign_in(user)
      put "/discourse-mod-categories/checklist.json", params: { items: [{ label: "x", url: "" }] }
      expect(response.status).to eq(403)
      expect(DiscourseModCategories.checklist_config).to be_nil
    end

    it "stores the trust-level cap and the accept-button label" do
      sign_in(moderator)

      put "/discourse-mod-categories/checklist.json",
          params: {
            items: [{ label: "Agree", url: "" }],
            max_tl: 1,
            button_label: "I understand",
          }

      expect(response.parsed_body["max_tl"]).to eq(1)
      expect(response.parsed_body["button_label"]).to eq("I understand")

      config = DiscourseModCategories.checklist_config
      expect(config["max_tl"]).to eq(1)
      expect(config["button_label"]).to eq("I understand")
    end

    it "defaults the trust-level cap to 2 and clamps out-of-range values" do
      sign_in(moderator)

      put "/discourse-mod-categories/checklist.json", params: { items: [{ label: "x", url: "" }] }
      expect(response.parsed_body["max_tl"]).to eq(2)

      put "/discourse-mod-categories/checklist.json",
          params: {
            items: [{ label: "x", url: "" }],
            max_tl: 9,
          }
      expect(response.parsed_body["max_tl"]).to eq(2)

      put "/discourse-mod-categories/checklist.json",
          params: {
            items: [{ label: "x", url: "" }],
            max_tl: -1,
          }
      expect(response.parsed_body["max_tl"]).to eq(0)
    end
  end

  describe "GET /discourse-mod-categories/checklist/owed" do
    it "returns the owed checklist for a TL0-TL2 user who has not accepted" do
      PluginStore.set(
        ns,
        key,
        { "version" => 1, "items" => [{ "label" => "Read the rules", "url" => "" }] },
      )
      sign_in(user)

      get "/discourse-mod-categories/checklist/owed.json"

      expect(response.status).to eq(200)
      checklist = response.parsed_body["checklist"]
      expect(checklist).to be_present
      expect(checklist["kind"]).to eq("global")
      expect(checklist["version"]).to eq(1)
      expect(checklist["items"].first["label"]).to eq("Read the rules")
    end

    it "returns null when the user owes nothing" do
      PluginStore.set(ns, key, { "version" => 1, "items" => [{ "label" => "x" }] })
      user.upsert_custom_fields(DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD => 1)
      sign_in(user)

      get "/discourse-mod-categories/checklist/owed.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["checklist"]).to be_nil
    end

    it "returns null for staff under the forum-wide checklist" do
      PluginStore.set(ns, key, { "version" => 1, "items" => [{ "label" => "x" }] })
      sign_in(moderator)

      get "/discourse-mod-categories/checklist/owed.json"

      expect(response.parsed_body["checklist"]).to be_nil
    end

    it "returns the new version after a mid-session version bump" do
      PluginStore.set(ns, key, { "version" => 1, "items" => [{ "label" => "x" }] })
      user.upsert_custom_fields(DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD => 1)
      sign_in(user)

      get "/discourse-mod-categories/checklist/owed.json"
      expect(response.parsed_body["checklist"]).to be_nil

      # Staff publish a newer version; the same session sees it.
      PluginStore.set(ns, key, { "version" => 2, "items" => [{ "label" => "y" }] })

      get "/discourse-mod-categories/checklist/owed.json"
      expect(response.parsed_body["checklist"]["version"]).to eq(2)
    end

    it "returns a targeted checklist for a targeted user" do
      PluginStore.set(
        ns,
        DiscourseModCategories::TARGETED_CHECKLISTS_KEY,
        [
          {
            "id" => "abc123",
            "name" => "Mods",
            "user_ids" => [user.id],
            "items" => [{ "label" => "Read this", "url" => "" }],
            "version" => 1,
            "button_label" => "OK",
          },
        ],
      )
      sign_in(user)

      get "/discourse-mod-categories/checklist/owed.json"

      checklist = response.parsed_body["checklist"]
      expect(checklist["kind"]).to eq("targeted")
      expect(checklist["id"]).to eq("abc123")
    end

    it "requires login" do
      get "/discourse-mod-categories/checklist/owed.json"
      expect(response.status).to eq(403)
    end
  end

  describe "checklist updated_at timestamp" do
    it "is stored and surfaced when staff save the forum-wide checklist" do
      sign_in(moderator)

      put "/discourse-mod-categories/checklist.json",
          params: {
            items: [{ label: "Agree", url: "" }],
          }
      expect(response.parsed_body["updated_at"]).to be_present
      first = DiscourseModCategories.checklist_config["updated_at"]
      expect(first).to be_present

      put "/discourse-mod-categories/checklist.json",
          params: {
            items: [{ label: "Agree again", url: "" }],
          }
      second = DiscourseModCategories.checklist_config["updated_at"]
      expect(second).to be_present
      expect(second >= first).to eq(true)
    end

    it "is exposed in the owed-checklist payload" do
      PluginStore.set(
        ns,
        key,
        {
          "version" => 1,
          "updated_at" => "2026-01-02T03:04:05Z",
          "items" => [{ "label" => "x", "url" => "" }],
        },
      )
      sign_in(user)

      get "/discourse-mod-categories/checklist/owed.json"
      expect(response.parsed_body["checklist"]["updated_at"]).to eq("2026-01-02T03:04:05Z")
    end

    it "is stored when staff create and update a targeted checklist" do
      sign_in(moderator)

      post "/discourse-mod-categories/checklist/targeted.json",
           params: {
             name: "App uploaders",
             user_ids: [user.id],
             items: [{ label: "x", url: "" }],
           }
      created = response.parsed_body["targeted"].first
      expect(created["updated_at"]).to be_present
      id = created["id"]

      put "/discourse-mod-categories/checklist/targeted/#{id}.json",
          params: {
            name: "Renamed",
            user_ids: [user.id],
            items: [{ label: "y", url: "" }],
          }
      updated = response.parsed_body["targeted"].first
      expect(updated["updated_at"]).to be_present
      expect(updated["updated_at"] >= created["updated_at"]).to eq(true)
    end
  end

  describe "POST /discourse-mod-categories/checklist/accept" do
    it "records the accepted version on the user" do
      PluginStore.set(ns, key, { "version" => 2, "items" => [{ "label" => "x" }] })
      sign_in(user)

      post "/discourse-mod-categories/checklist/accept.json", params: { version: 2 }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields[DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD]).to eq(
        2,
      )
    end

    it "clamps the accepted version to the published version" do
      PluginStore.set(ns, key, { "version" => 2, "items" => [{ "label" => "x" }] })
      sign_in(user)

      post "/discourse-mod-categories/checklist/accept.json", params: { version: 99 }

      expect(user.reload.custom_fields[DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD]).to eq(
        2,
      )
    end
  end

  describe "acceptance audit log" do
    let(:log_key) { DiscourseModCategories::CHECKLIST_LOG_KEY }

    it "appends an entry each time a user accepts" do
      PluginStore.set(ns, key, { "version" => 1, "items" => [{ "label" => "x" }] })
      sign_in(user)

      post "/discourse-mod-categories/checklist/accept.json", params: { version: 1 }

      entries = PluginStore.get(ns, log_key)
      expect(entries.size).to eq(1)
      expect(entries.first["user_id"]).to eq(user.id)
      expect(entries.first["version"]).to eq(1)
      expect(entries.first["at"]).to be_present
    end

    it "is returned by the show endpoint, newest first, with usernames" do
      PluginStore.set(ns, key, { "version" => 2, "items" => [{ "label" => "x" }] })
      other = Fabricate(:user, trust_level: TrustLevel[0])

      sign_in(user)
      post "/discourse-mod-categories/checklist/accept.json", params: { version: 2 }
      sign_in(other)
      post "/discourse-mod-categories/checklist/accept.json", params: { version: 2 }

      sign_in(moderator)
      get "/discourse-mod-categories/checklist.json"

      log = response.parsed_body["log"]
      expect(log.size).to eq(2)
      expect(log.first["username"]).to eq(other.username)
      expect(log.last["username"]).to eq(user.username)
      expect(log.first["version"]).to eq(2)
    end
  end

  describe "current-user serializer" do
    before do
      PluginStore.set(
        ns,
        key,
        { "version" => 1, "items" => [{ "label" => "Read the rules", "url" => "" }] },
      )
    end

    it "exposes the checklist to a TL0-TL2 user who has not accepted it" do
      [TrustLevel[0], TrustLevel[1], TrustLevel[2]].each do |tl|
        target = Fabricate(:user, trust_level: tl)
        checklist = serialized(target)[:mod_first_post_checklist]
        expect(checklist).to be_present
        expect(checklist[:version]).to eq(1)
      end
    end

    it "does not expose the checklist to a TL3 user" do
      target = Fabricate(:user, trust_level: TrustLevel[3])
      expect(serialized(target)[:mod_first_post_checklist]).to be_nil
    end

    it "does not expose the checklist to staff" do
      expect(serialized(moderator)[:mod_first_post_checklist]).to be_nil
      expect(serialized(admin)[:mod_first_post_checklist]).to be_nil
    end

    it "stops exposing the checklist once the user has accepted it" do
      user.custom_fields[DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD] = 1
      user.save_custom_fields(true)
      expect(serialized(user)[:mod_first_post_checklist]).to be_nil
    end

    it "exposes the checklist again after a new version is published" do
      user.custom_fields[DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD] = 1
      user.save_custom_fields(true)
      PluginStore.set(
        ns,
        key,
        { "version" => 2, "items" => [{ "label" => "Updated rule", "url" => "" }] },
      )
      expect(serialized(user)[:mod_first_post_checklist][:version]).to eq(2)
    end

    it "exposes nothing when the checklist has no items" do
      PluginStore.set(ns, key, { "version" => 5, "items" => [] })
      expect(serialized(user)[:mod_first_post_checklist]).to be_nil
    end

    it "honours a trust-level cap below the default" do
      PluginStore.set(
        ns,
        key,
        { "version" => 1, "max_tl" => 1, "items" => [{ "label" => "Agree", "url" => "" }] },
      )
      tl1 = Fabricate(:user, trust_level: TrustLevel[1])
      tl2 = Fabricate(:user, trust_level: TrustLevel[2])

      expect(serialized(tl1)[:mod_first_post_checklist]).to be_present
      expect(serialized(tl2)[:mod_first_post_checklist]).to be_nil
    end

    it "exposes the configured accept-button label" do
      PluginStore.set(
        ns,
        key,
        {
          "version" => 1,
          "button_label" => "I understand",
          "items" => [{ "label" => "Agree", "url" => "" }],
        },
      )
      checklist = serialized(user)[:mod_first_post_checklist]
      expect(checklist[:button_label]).to eq("I understand")
    end

    it "tags the forum-wide checklist with kind 'global'" do
      expect(serialized(user)[:mod_first_post_checklist][:kind]).to eq("global")
    end

    it "exposes the stored updated_at timestamp" do
      PluginStore.set(
        ns,
        key,
        {
          "version" => 1,
          "updated_at" => "2026-01-02T03:04:05Z",
          "items" => [{ "label" => "Agree", "url" => "" }],
        },
      )
      checklist = serialized(user)[:mod_first_post_checklist]
      expect(checklist[:updated_at]).to eq("2026-01-02T03:04:05Z")
    end
  end

  describe "POST /discourse-mod-categories/checklist/require-reaccept" do
    it "lets a moderator reset a user's accepted version to 0" do
      user.upsert_custom_fields(DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD => 5)
      sign_in(moderator)

      post "/discourse-mod-categories/checklist/require-reaccept.json",
           params: {
             username: user.username,
           }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields[DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD]).to eq(
        0,
      )
    end

    it "accepts a user_id as well" do
      user.upsert_custom_fields(DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD => 3)
      sign_in(admin)

      post "/discourse-mod-categories/checklist/require-reaccept.json", params: { user_id: user.id }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields[DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD]).to eq(
        0,
      )
    end

    it "forbids a regular user" do
      sign_in(user)
      post "/discourse-mod-categories/checklist/require-reaccept.json",
           params: {
             username: moderator.username,
           }
      expect(response.status).to eq(403)
    end

    it "404s for an unknown user" do
      sign_in(moderator)
      post "/discourse-mod-categories/checklist/require-reaccept.json",
           params: {
             username: "nobody-here",
           }
      expect(response.status).to eq(404)
    end
  end

  describe "targeted checklists" do
    let(:targeted_key) { DiscourseModCategories::TARGETED_CHECKLISTS_KEY }
    let(:targeted_field) { DiscourseModCategories::USER_TARGETED_CHECKLIST_FIELD }

    it "lets a moderator create a targeted checklist starting at version 1" do
      sign_in(moderator)

      post "/discourse-mod-categories/checklist/targeted.json",
           params: {
             name: "App uploaders",
             user_ids: [user.id],
             button_label: "I agree",
             items: [{ label: "Read the app rules", url: "" }],
           }

      expect(response.status).to eq(200)
      list = response.parsed_body["targeted"]
      expect(list.size).to eq(1)
      expect(list.first["name"]).to eq("App uploaders")
      expect(list.first["version"]).to eq(1)
      expect(list.first["user_ids"]).to eq([user.id])
      expect(list.first["id"]).to be_present
    end

    it "lets a moderator update a targeted checklist and bumps its version" do
      sign_in(moderator)
      post "/discourse-mod-categories/checklist/targeted.json",
           params: {
             name: "Original",
             user_ids: [user.id],
             items: [{ label: "x", url: "" }],
           }
      id = response.parsed_body["targeted"].first["id"]

      put "/discourse-mod-categories/checklist/targeted/#{id}.json",
          params: {
            name: "Renamed",
            user_ids: [user.id],
            items: [{ label: "y", url: "" }],
          }

      expect(response.status).to eq(200)
      checklist = response.parsed_body["targeted"].first
      expect(checklist["name"]).to eq("Renamed")
      expect(checklist["version"]).to eq(2)
    end

    it "lets a moderator delete a targeted checklist" do
      sign_in(moderator)
      post "/discourse-mod-categories/checklist/targeted.json",
           params: {
             name: "Doomed",
             user_ids: [user.id],
             items: [{ label: "x", url: "" }],
           }
      id = response.parsed_body["targeted"].first["id"]

      delete "/discourse-mod-categories/checklist/targeted/#{id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["targeted"]).to eq([])
    end

    it "drops user ids that are not real users" do
      sign_in(moderator)
      post "/discourse-mod-categories/checklist/targeted.json",
           params: {
             name: "Filtered",
             user_ids: [user.id, 999_999],
             items: [{ label: "x", url: "" }],
           }
      expect(response.parsed_body["targeted"].first["user_ids"]).to eq([user.id])
    end

    it "forbids a regular user from the management endpoints" do
      sign_in(user)

      post "/discourse-mod-categories/checklist/targeted.json",
           params: {
             name: "Nope",
             user_ids: [user.id],
             items: [{ label: "x", url: "" }],
           }
      expect(response.status).to eq(403)

      put "/discourse-mod-categories/checklist/targeted/abc.json", params: { name: "Nope" }
      expect(response.status).to eq(403)

      delete "/discourse-mod-categories/checklist/targeted/abc.json"
      expect(response.status).to eq(403)
    end

    it "returns a targeted checklist to a targeted staff member" do
      PluginStore.set(
        ns,
        targeted_key,
        [
          {
            "id" => "abc123",
            "name" => "Mods",
            "user_ids" => [moderator.id],
            "items" => [{ "label" => "Read this", "url" => "" }],
            "version" => 1,
            "button_label" => "OK",
          },
        ],
      )

      checklist = serialized(moderator)[:mod_first_post_checklist]
      expect(checklist).to be_present
      expect(checklist[:kind]).to eq("targeted")
      expect(checklist[:id]).to eq("abc123")
    end

    it "returns a targeted checklist to a targeted high-trust user" do
      tl4 = Fabricate(:user, trust_level: TrustLevel[4])
      PluginStore.set(
        ns,
        targeted_key,
        [
          {
            "id" => "tl4check",
            "name" => "Veterans",
            "user_ids" => [tl4.id],
            "items" => [{ "label" => "Read this", "url" => "" }],
            "version" => 1,
            "button_label" => "",
          },
        ],
      )

      checklist = serialized(tl4)[:mod_first_post_checklist]
      expect(checklist).to be_present
      expect(checklist[:kind]).to eq("targeted")
    end

    it "does not show a targeted checklist to a user not listed" do
      PluginStore.set(
        ns,
        targeted_key,
        [
          {
            "id" => "abc123",
            "name" => "Mods",
            "user_ids" => [moderator.id],
            "items" => [{ "label" => "Read this", "url" => "" }],
            "version" => 1,
            "button_label" => "",
          },
        ],
      )
      expect(serialized(user)[:mod_first_post_checklist]).to be_nil
    end

    it "accept with kind 'targeted' records to the per-checklist map and clamps" do
      PluginStore.set(
        ns,
        targeted_key,
        [
          {
            "id" => "abc123",
            "name" => "Mods",
            "user_ids" => [user.id],
            "items" => [{ "label" => "x", "url" => "" }],
            "version" => 2,
            "button_label" => "",
          },
        ],
      )
      sign_in(user)

      post "/discourse-mod-categories/checklist/accept.json",
           params: {
             kind: "targeted",
             id: "abc123",
             version: 99,
           }

      expect(response.status).to eq(200)
      map = user.reload.custom_fields[targeted_field]
      expect(map["abc123"]).to eq(2)
      # The global field is untouched.
      expect(user.custom_fields[DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD]).to be_nil
    end

    it "stops showing a targeted checklist once accepted, until bumped" do
      PluginStore.set(
        ns,
        targeted_key,
        [
          {
            "id" => "abc123",
            "name" => "Mods",
            "user_ids" => [user.id],
            "items" => [{ "label" => "x", "url" => "" }],
            "version" => 1,
            "button_label" => "",
          },
        ],
      )
      user.upsert_custom_fields(targeted_field => { "abc123" => 1 })
      expect(serialized(user)[:mod_first_post_checklist]).to be_nil

      PluginStore.set(
        ns,
        targeted_key,
        [
          {
            "id" => "abc123",
            "name" => "Mods",
            "user_ids" => [user.id],
            "items" => [{ "label" => "x", "url" => "" }],
            "version" => 2,
            "button_label" => "",
          },
        ],
      )
      expect(serialized(user.reload)[:mod_first_post_checklist][:kind]).to eq("targeted")
    end

    it "shows the targeted list in the staff show endpoint" do
      PluginStore.set(
        ns,
        targeted_key,
        [
          {
            "id" => "abc123",
            "name" => "Mods",
            "user_ids" => [user.id],
            "items" => [{ "label" => "x", "url" => "" }],
            "version" => 1,
            "button_label" => "",
          },
        ],
      )
      sign_in(moderator)
      get "/discourse-mod-categories/checklist.json"
      expect(response.parsed_body["targeted"].first["id"]).to eq("abc123")
    end
  end
end
