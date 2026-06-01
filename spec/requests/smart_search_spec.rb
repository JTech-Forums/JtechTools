# frozen_string_literal: true

require "rails_helper"

# End-to-end coverage for the smart-search sub-plugin. Exercises the
# Search prepend by driving the standard /search.json endpoint with
# terms that only match via a synonym, and verifies the gracefull
# fall-back paths so a misbehaving expansion can never break search.
RSpec.describe "Smart search" do
  fab!(:category)
  fab!(:user)
  fab!(:child_topic) do
    Fabricate(
      :topic,
      category: category,
      title: "Helping my child with morning routines",
    )
  end
  fab!(:child_post) do
    Fabricate(
      :post,
      topic: child_topic,
      user: user,
      raw: "Tips for working with a young child who refuses transitions.",
    )
  end

  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  def reindex(post)
    SearchIndexer.index(post, force: true)
    SearchIndexer.index(post.topic, force: true)
  end

  before { reindex(child_post) }

  describe "with smart_search disabled" do
    before { SiteSetting.smart_search_enabled = false }

    it "behaves exactly like vanilla Discourse search" do
      result = ::Search.execute("kid")
      # Vanilla search does not match "child" content for the query
      # "kid", so the post is NOT expected to be in the result set.
      expect(result.posts.map(&:id)).not_to include(child_post.id)
    end
  end

  describe "with smart_search enabled" do
    before do
      SiteSetting.smart_search_enabled = true
      SiteSetting.smart_search_minimum_results = 5
      SiteSetting.smart_search_variant_limit = 2
    end

    it "finds posts that match only via a synonym" do
      result = ::Search.execute("kid")
      expect(result.posts.map(&:id)).to include(child_post.id)
    end

    it "does not duplicate posts that match both the original and a variant" do
      kid_topic =
        Fabricate(
          :topic,
          category: category,
          title: "Asking a kid about their day",
        )
      kid_post =
        Fabricate(
          :post,
          topic: kid_topic,
          user: user,
          raw: "What helps a kid open up at dinner?",
        )
      reindex(kid_post)

      result = ::Search.execute("kid")
      ids = result.posts.map(&:id)
      expect(ids.count(kid_post.id)).to eq(1)
    end

    it "skips variant expansion when the original returns enough results" do
      # Threshold of 0 means "never bother running variants" because
      # the original always returns >= 0 results.
      SiteSetting.smart_search_minimum_results = 0
      result = ::Search.execute("kid")
      expect(result.posts.map(&:id)).not_to include(child_post.id)
    end

    it "does not raise when Synonyms.for raises" do
      allow(::DiscourseSmartSearch::Synonyms).to receive(:for).and_raise("boom")
      # The vanilla pass must complete and return a result object; the
      # synonym-lookup failure inside the variant expansion is caught
      # by the rescue and the original result is returned untouched.
      expect { ::Search.execute("kid") }.not_to raise_error
    end

    it "does not raise when QueryExpander raises" do
      allow(::DiscourseSmartSearch::QueryExpander).to receive(:variants).and_raise("boom")
      expect { ::Search.execute("kid") }.not_to raise_error
    end

    it "does not raise when an inner variant Search.new raises" do
      # Make the variant generator return one alt term, then make any
      # Search.new for that term blow up. The rescue around
      # merge_variant should swallow it and return the original result.
      allow(::DiscourseSmartSearch::QueryExpander).to receive(:variants).and_return(
        ["___injected_alt___"],
      )
      original_new = ::Search.method(:new)
      allow(::Search).to receive(:new) do |term, *rest|
        raise "exploded" if term == "___injected_alt___"
        original_new.call(term, *rest)
      end

      expect { ::Search.execute("kid") }.not_to raise_error
    end

    it "passes the configured limit through to QueryExpander.variants" do
      SiteSetting.smart_search_variant_limit = 1
      received_limit = nil
      allow(::DiscourseSmartSearch::QueryExpander).to receive(:variants) do |_term, **opts|
        received_limit = opts[:limit]
        []
      end
      ::Search.execute("kid behavior")
      expect(received_limit).to eq(1)
    end

    it "preserves Discourse operators on the variant queries" do
      # An exact-search operator query should remain expandable but the
      # operator itself must travel through verbatim.
      variants = ::DiscourseSmartSearch::QueryExpander.variants("kid category:general")
      variants.each { |v| expect(v).to include("category:general") }
    end
  end
end
