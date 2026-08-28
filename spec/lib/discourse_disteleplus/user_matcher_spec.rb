# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::UserMatcher do
  fab!(:alice) { Fabricate(:user, username: "alice") }
  fab!(:bob) { Fabricate(:user, username: "bob") }

  def from(username)
    { "id" => 1, "username" => username }
  end

  it "matches automatically on the same username" do
    expect(described_class.match(from("alice"))).to eq(alice)
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

  describe "manual mappings" do
    before { SiteSetting.disteleplus_user_mappings = "tg_alice:bob|@Weird_TG:alice" }

    it "wins over the automatic match" do
      SiteSetting.disteleplus_user_mappings = "alice:bob"
      expect(described_class.match(from("alice"))).to eq(bob)
    end

    it "maps distinct Telegram usernames" do
      expect(described_class.match(from("tg_alice"))).to eq(bob)
    end

    it "strips @ prefixes and downcases the Telegram side" do
      expect(described_class.match(from("weird_tg"))).to eq(alice)
    end

    it "ignores malformed pairs" do
      SiteSetting.disteleplus_user_mappings = "justoneword|:missing|also:"
      expect(described_class.mappings).to eq({})
    end
  end
end
