# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::EmojiMap do
  it "maps common Discourse emoji to Telegram reaction chars" do
    expect(described_class.discourse_to_tg("+1")).to eq("👍")
    expect(described_class.discourse_to_tg(":fire:")).to eq("🔥")
    expect(described_class.discourse_to_tg("heart")).to eq("❤")
  end

  it "falls back to 👍 for unmapped Discourse emoji" do
    expect(described_class.discourse_to_tg("some_exotic_emoji")).to eq("👍")
  end

  it "maps Telegram chars back to canonical Discourse names" do
    expect(described_class.tg_to_discourse("👍")).to eq("+1")
    expect(described_class.tg_to_discourse("🔥")).to eq("fire")
    expect(described_class.tg_to_discourse("🤣")).to eq("joy")
  end

  it "falls back to :+1: for unmapped Telegram chars" do
    expect(described_class.tg_to_discourse("🦖")).to eq("+1")
  end

  it "keeps the inversion sane — every canonical name round-trips" do
    described_class::TG_TO_DISCOURSE.each do |char, name|
      expect(described_class.discourse_to_tg(name)).to eq(char)
    end
  end
end
