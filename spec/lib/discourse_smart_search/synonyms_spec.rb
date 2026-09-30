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

      it "resolves from any member of the group" do
        expect(described_class.for("javascript")).to include("js")
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

      it "leaves out multi-word entries and WordNet's part-of-speech markers" do
        set = described_class.for("future")
        expect(set.none? { |w| w.include?(" ") || w.include?("(") }).to eq(true)
      end

      it "caps results at MAX_SYNONYMS_PER_WORD to avoid runaway expansion" do
        # "set" is famously polysemous (50+ senses), so the cap matters.
        expect(described_class.for("set").size).to be <= described_class::MAX_SYNONYMS_PER_WORD
      end
    end

    context "fallback when WordNet is unavailable" do
      # Set the memoized @wordnet_available directly rather than stubbing
      # via `allow(...).to receive(:wordnet_available?)`. RSpec's stub on
      # a public class method doesn't reliably intercept the internal
      # `self.wordnet_available?` call inside `wordnet_synonyms_for`
      # — private same-module call resolution can bypass the mock.
      # Setting the memoized variable triggers the early-return path
      # inside `wordnet_available?` and works regardless of call site.
      before { described_class.instance_variable_set(:@wordnet_available, false) }

      after { described_class.instance_variable_set(:@wordnet_available, nil) }

      it "returns [word] for a general English word the overlay doesn't cover" do
        # "happy" is NOT in the overlay (WordNet covers it). With
        # WordNet marked unavailable, the lookup falls through to
        # `[key]`. Earlier the test used "bug" but the overlay later
        # gained a tech-meaning override for that word, so it now hits
        # the overlay path first.
        expect(described_class.for("happy")).to eq(["happy"])
      end

      it "still resolves overlay entries (tech jargon)" do
        # Overlay always works even without WordNet.
        expect(described_class.for("js")).to include("javascript")
      end
    end
  end

  describe "the dictionary" do
    it "tolerates a missing or malformed file" do
      expect(described_class.send(:load_groups, "/nonexistent/path.yml")).to eq([])

      tmp = ::Tempfile.new(%w[smart_search_bad .yml])
      tmp.write("[[[unbalanced")
      tmp.close
      expect(described_class.send(:load_groups, tmp.path)).to eq([])
    ensure
      tmp&.unlink
    end

    it "keeps each group's order so the clearest term is offered first" do
      expect(described_class.for("k8s")).to eq(%w[k8s kubernetes])
      expect(described_class.for("kubernetes")).to eq(%w[kubernetes k8s])
    end

    it "picks up the site's extra synonyms as soon as the setting changes" do
      SiteSetting.smart_search_extra_synonyms = "supercalifragilistic,mary-poppins"
      expect(described_class.for("supercalifragilistic")).to include("mary-poppins")

      SiteSetting.smart_search_extra_synonyms = ""
      expect(described_class.for("supercalifragilistic")).to eq(["supercalifragilistic"])
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
