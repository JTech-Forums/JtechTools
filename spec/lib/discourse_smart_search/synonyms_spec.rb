# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseSmartSearch::Synonyms do
  describe ".for" do
    it "returns the symmetric synonym set including the word itself" do
      set = described_class.for("kid")
      expect(set).to include("kid")
      expect(set).to include("child")
    end

    it "is order-independent — any group member resolves the same group" do
      via_kid = described_class.for("kid")
      via_child = described_class.for("child")
      expect(via_kid).to eq(via_child)
    end

    it "downcases the input before lookup" do
      expect(described_class.for("KID")).to include("child")
    end

    it "trims surrounding whitespace" do
      expect(described_class.for("  kid  ")).to include("child")
    end

    it "returns the word alone for an unknown word" do
      expect(described_class.for("xyzzyplotch")).to eq(["xyzzyplotch"])
    end

    it "returns [] for blank input" do
      expect(described_class.for(nil)).to eq([])
      expect(described_class.for("")).to eq([])
      expect(described_class.for("   ")).to eq([])
    end

    it "merges synonyms when a word appears in multiple groups" do
      described_class.reload!(extras: [%w[behavior conduct], %w[behavior pattern habit]])
      set = described_class.for("behavior")
      expect(set).to include("conduct")
      expect(set).to include("pattern")
      expect(set).to include("habit")
    ensure
      described_class.reload!
    end

    it "ignores groups with fewer than two entries" do
      described_class.reload!(extras: [["solo"]])
      expect(described_class.for("solo")).to eq(["solo"])
    ensure
      described_class.reload!
    end
  end

  describe ".reload!" do
    it "tolerates a missing dictionary file" do
      expect { described_class.reload!(path: "/nonexistent/path.yml") }.not_to raise_error
      expect(described_class.for("kid")).to eq(["kid"])
    ensure
      described_class.reload!
    end

    it "tolerates a malformed dictionary file" do
      tmp = ::Tempfile.new(%w[smart_search_bad .yml])
      tmp.write("[[[unbalanced")
      tmp.close
      expect { described_class.reload!(path: tmp.path) }.not_to raise_error
      expect(described_class.for("kid")).to eq(["kid"])
    ensure
      tmp&.close
      tmp&.unlink
      described_class.reload!
    end
  end
end
