# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::UserMatcher do
  fab!(:alice) { Fabricate(:user, username: "alice") }
  fab!(:bob) { Fabricate(:user, username: "bob") }

  def from(username)
    { "id" => 1, "username" => username }
  end

  def map!(*pairs)
    SiteSetting.disteleplus_user_map =
      pairs.map { |tg, dc| { "telegram_username" => tg, "discourse_username" => dc } }.to_json
  end

  it "matches automatically on the same username" do
    expect(described_class.match(from("alice"))).to eq(alice)
  end

  it "never auto-matches staff by bare username" do
    mod = Fabricate(:moderator, username: "modface")
    expect(described_class.match(from("modface"))).to be_nil
    SiteSetting.disteleplus_user_map = [
      { "telegram_username" => "modface", "discourse_username" => "modface" },
    ].to_json
    expect(described_class.match(from("modface"))).to eq(mod)
  end

  it "respects disteleplus_auto_match_usernames = false" do
    SiteSetting.disteleplus_auto_match_usernames = false
    expect(described_class.match(from("alice"))).to be_nil
  end

  it "prefers a numeric telegram_id row over everything" do
    SiteSetting.disteleplus_user_map = [
      { "telegram_username" => "whatever", "discourse_username" => "bob", "telegram_id" => "1" },
    ].to_json
    expect(described_class.match(from("alice"))).to eq(bob)
  end

  describe ".privileged_match" do
    it "only honors explicit numeric telegram_id rows" do
      map!(%w[alice alice])
      expect(described_class.privileged_match(from("alice"))).to be_nil

      SiteSetting.disteleplus_user_map = [
        { "telegram_username" => "alice", "discourse_username" => "alice", "telegram_id" => "1" },
      ].to_json
      expect(described_class.privileged_match(from("alice"))).to eq(alice)
      expect(described_class.privileged_match({ "id" => 2, "username" => "alice" })).to be_nil
    end
  end

  it "matches case-insensitively" do
    expect(described_class.match(from("ALICE"))).to eq(alice)
  end

  it "returns nil for unknown usernames" do
    expect(described_class.match(from("nobody"))).to be_nil
  end

  it "returns nil for Telegram users without a username" do
    expect(described_class.match("id" => 1)).to be_nil
    expect(described_class.match(nil)).to be_nil
  end

  describe "manual mappings (disteleplus_user_map)" do
    before { map!(%w[tg_alice bob], %w[@Weird_TG alice]) }

    it "wins over the automatic match" do
      map!(%w[alice bob])
      expect(described_class.match(from("alice"))).to eq(bob)
    end

    it "maps distinct Telegram usernames" do
      expect(described_class.match(from("tg_alice"))).to eq(bob)
    end

    it "strips @ prefixes and downcases the Telegram side" do
      expect(described_class.match(from("weird_tg"))).to eq(alice)
    end

    it "falls back to the automatic match when the mapped user is gone" do
      map!(%w[alice no_such_user_anymore])
      expect(described_class.match(from("alice"))).to eq(alice)
    end

    it "tolerates a malformed stored value" do
      SiteSetting.disteleplus_user_map = "[]"
      expect(described_class.rows("not json at all")).to eq([])
      expect(described_class.mappings).to eq({})
    end
  end

  describe "legacy disteleplus_user_mappings migration shape" do
    it "parses the pipe format the migration converts" do
      rows =
        "tg_alice:bob|@Weird_TG:alice|justoneword|:missing|also:"
          .split("|")
          .filter_map do |pair|
            tg, dc = pair.split(":", 2)
            tg = tg.to_s.strip.delete_prefix("@")
            dc = dc.to_s.strip.delete_prefix("@")
            next if tg.blank? || dc.blank?
            { "telegram_username" => tg, "discourse_username" => dc }
          end
      expect(rows).to eq(
        [
          { "telegram_username" => "tg_alice", "discourse_username" => "bob" },
          { "telegram_username" => "Weird_TG", "discourse_username" => "alice" },
        ],
      )
    end
  end
end
