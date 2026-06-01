# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseSmartSearch::Synonyms do
  # Clear the LRU cache between examples so a prior test's stubbed
  # `wordnet_available?` return value doesn't leak into another test
  # via a cache hit.
  before { described_class.reload! }
  before { described_class.instance_variable_set(:@wordnet_available, nil) }

  describe ".for" do
    context "tech overlay (YAML) — always available" do
      it "returns the symmetric synonym set including the word itself" do
        set = described_class.for("js")
        expect(set).to include("js")
        expect(set).to include("javascript")
      end

      it "is order-independent — any group member resolves the same group" do
        via_js = described_class.for("js")
        via_javascript = described_class.for("javascript")
        expect(via_js).to eq(via_javascript)
      end

      it "downcases the input before lookup" do
        expect(described_class.for("JS")).to include("javascript")
      end

      it "trims surrounding whitespace" do
        expect(described_class.for("  js  ")).to include("javascript")
      end

      it "returns [] for blank input" do
        expect(described_class.for(nil)).to eq([])
        expect(described_class.for("")).to eq([])
        expect(described_class.for("   ")).to eq([])
      end
    end

    context "WordNet backend — only when the gem is loadable" do
      before { skip "WordNet gem unavailable" unless described_class.wordnet_available? }

      it "expands a general English word with WordNet synonyms" do
        set = described_class.for("bug")
        expect(set).to include("bug")
        # WordNet's "bug" synsets include defect, glitch, fault — at
        # least one of those should be present.
        expect(set & %w[defect glitch fault]).not_to be_empty
      end

      it "returns the word alone for a nonsense input" do
        # WordNet has no entry for "xyzzyplotch", so we fall through to
        # the [word] default.
        expect(described_class.for("xyzzyplotch")).to eq(["xyzzyplotch"])
      end

      it "caps results at MAX_SYNONYMS_PER_WORD to avoid runaway expansion" do
        # "set" is famously polysemous (50+ senses), so the cap matters.
        expect(described_class.for("set").size).to be <= described_class::MAX_SYNONYMS_PER_WORD
      end
    end

    context "fallback when WordNet is unavailable" do
      before { allow(described_class).to receive(:wordnet_available?).and_return(false) }

      it "returns [word] for a general English word the overlay doesn't cover" do
        # "bug" is NOT in the overlay (WordNet covers it). With WordNet
        # stubbed unavailable, the lookup falls through to [key].
        expect(described_class.for("bug")).to eq(["bug"])
      end

      it "still resolves overlay entries (tech jargon)" do
        # Overlay always works even without WordNet.
        expect(described_class.for("js")).to include("javascript")
      end
    end
  end

  describe ".reload!" do
    it "tolerates a missing overlay file" do
      expect { described_class.reload!(path: "/nonexistent/path.yml") }.not_to raise_error
      # Overlay is empty after a failed load; tech entries are gone
      # until reload! is called again with the real path.
    ensure
      described_class.reload!
    end

    it "tolerates a malformed overlay file" do
      tmp = ::Tempfile.new(%w[smart_search_bad .yml])
      tmp.write("[[[unbalanced")
      tmp.close
      expect { described_class.reload!(path: tmp.path) }.not_to raise_error
    ensure
      tmp&.close
      tmp&.unlink
      described_class.reload!
    end

    it "accepts an `extras:` array to inject extra groups for testing" do
      described_class.reload!(extras: [%w[supercalifragilistic mary-poppins]])
      expect(described_class.for("supercalifragilistic")).to include("mary-poppins")
    ensure
      described_class.reload!
    end
  end

  describe "caching" do
    it "returns the same array object on a second call (memoized)" do
      first = described_class.for("js")
      second = described_class.for("js")
      expect(second).to equal(first)
    end
  end
end
