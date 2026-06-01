# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseSmartSearch::QueryExpander do
  describe ".variants" do
    it "substitutes a single content word with its top synonym" do
      variants = described_class.variants("js")
      expect(variants).to be_an(Array)
      expect(variants).not_to be_empty
      expect(variants.first).not_to eq("js")
      expect(::DiscourseSmartSearch::Synonyms.for("js")).to include(variants.first)
    end

    it "returns at most the requested limit" do
      variants = described_class.variants("js bug", limit: 1)
      expect(variants.size).to be <= 1
    end

    it "returns an empty array when nothing is expandable" do
      expect(described_class.variants("xyzzyplotch fnordwidget")).to eq([])
    end

    it "returns an empty array for blank input" do
      expect(described_class.variants(nil)).to eq([])
      expect(described_class.variants("")).to eq([])
    end

    it "preserves Discourse advanced-search operators verbatim" do
      variants = described_class.variants("js category:general tags:foo")
      expect(variants).not_to be_empty
      variants.each do |v|
        expect(v).to include("category:general")
        expect(v).to include("tags:foo")
      end
    end

    it "preserves quoted phrases verbatim" do
      variants = described_class.variants('js "exact phrase here"')
      expect(variants).not_to be_empty
      variants.each { |v| expect(v).to include('"exact phrase here"') }
    end

    it "preserves @mentions and #tags verbatim" do
      variants = described_class.variants("js @alice #performance")
      expect(variants).not_to be_empty
      variants.each do |v|
        expect(v).to include("@alice")
        expect(v).to include("#performance")
      end
    end

    it "skips stop-words even when other content is present" do
      variants = described_class.variants("the js")
      # The original word "the" must never get a synonym variant.
      variants.each { |v| expect(v.split(/\s+/)).to include("the") }
    end

    it "skips single-letter tokens" do
      variants = described_class.variants("a js")
      variants.each { |v| expect(v.split(/\s+/).first).to eq("a") }
    end

    it "never includes the original term in the variants" do
      variants = described_class.variants("js bug")
      expect(variants).not_to include("js bug")
    end

    it "substitutes every expandable token in the full-swap variant" do
      variants = described_class.variants("js bug")
      expect(variants).not_to be_empty
      full = variants.first.split(/\s+/)
      expect(full[0]).not_to eq("js")
      expect(full[1]).not_to eq("bug")
    end
  end
end
