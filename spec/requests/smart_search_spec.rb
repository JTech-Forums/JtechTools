# frozen_string_literal: true

require "rails_helper"

# End-to-end coverage for smart search through real searches. Uses made-up
# words as the synonym pair (via smart_search_extra_synonyms) so core's own
# tokenizer and stemmer can't connect them, which leaves smart search as the
# only way the synonym post is found.
RSpec.describe "Smart search" do
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, category: category, title: "Getting started with quintessify") }
  fab!(:synonym_post) do
    Fabricate(:post, topic: topic, user: user, raw: "A long guide about quintessify setups.")
  end

  before do
    SearchIndexer.enable
    SiteSetting.smart_search_enabled = true
    SiteSetting.smart_search_minimum_results = 5
    SiteSetting.smart_search_extra_synonyms = "zorbleflux,quintessify"
    reindex(synonym_post)
  end

  after { SearchIndexer.disable }

  def reindex(post)
    SearchIndexer.index(post, force: true)
    SearchIndexer.index(post.topic, force: true)
  end

  def post_ids(term, **opts)
    ::Search.execute(term, { guardian: Guardian.new(user) }.merge(opts)).posts.map(&:id)
  end

  it "does nothing while switched off" do
    SiteSetting.smart_search_enabled = false
    expect(post_ids("zorbleflux")).to be_empty
  end

  it "finds posts that only match a synonym" do
    expect(post_ids("zorbleflux")).to include(synonym_post.id)
    expect(post_ids("zorbleflux", search_type: :full_page)).to include(synonym_post.id)
  end

  it "keeps the search's filters on the retry" do
    expect(post_ids("zorbleflux ##{category.slug}")).to include(synonym_post.id)
    expect(post_ids("zorbleflux ##{other_category.slug}")).to be_empty
    expect(post_ids("zorbleflux in:title", search_type: :full_page)).to include(synonym_post.id)
    expect(post_ids("zorbleflux @nobody_here", search_type: :full_page)).to be_empty
  end

  it "never shows posts the searcher can't see" do
    secret = Fabricate(:private_category, group: Fabricate(:group))
    hidden =
      Fabricate(:post, topic: Fabricate(:topic, category: secret), raw: "quintessify internals")
    reindex(hidden)

    expect(post_ids("zorbleflux")).not_to include(hidden.id)
  end

  it "lists a topic once even when several of its posts match the synonym" do
    second = Fabricate(:post, topic: topic, raw: "More quintessify notes from another member.")
    reindex(second)

    results = ::Search.execute("zorbleflux", guardian: Guardian.new(user), search_type: :full_page)
    expect(results.posts.map(&:topic_id).count(topic.id)).to eq(1)
  end

  it "only expands the first page" do
    expect(
      post_ids("zorbleflux", search_type: :full_page, type_filter: "topic", page: 2),
    ).to be_empty
  end

  it "doesn't expand a search that already found enough" do
    SiteSetting.smart_search_minimum_results = 1
    direct = Fabricate(:post, raw: "zorbleflux itself, mentioned directly")
    reindex(direct)

    ids = post_ids("zorbleflux")
    expect(ids).to include(direct.id)
    expect(ids).not_to include(synonym_post.id)
  end

  it "logs only what the user typed" do
    SiteSetting.log_search_queries = true
    ::Search.execute(
      "zorbleflux",
      guardian: Guardian.new(user),
      search_type: :full_page,
      ip_address: "127.0.0.1",
      user_id: user.id,
    )

    expect(SearchLog.pluck(:term)).to eq(["zorbleflux"])
  end

  describe "failures" do
    it "fall back to the plain result when synonym lookup raises" do
      allow(::DiscourseSmartSearch::Synonyms).to receive(:for).and_raise("boom")
      expect { ::Search.execute("zorbleflux") }.not_to raise_error
    end

    it "fall back when a retry raises" do
      allow(::DiscourseSmartSearch::QueryExpander).to receive(:variants).and_return(["___alt___"])
      original_new = ::Search.method(:new)
      allow(::Search).to receive(:new) do |term, *rest|
        raise "exploded" if term == "___alt___"
        original_new.call(term, *rest)
      end

      expect { ::Search.execute("zorbleflux") }.not_to raise_error
    end
  end

  it "passes the configured variant limit through" do
    SiteSetting.smart_search_variant_limit = 1
    received = nil
    allow(::DiscourseSmartSearch::QueryExpander).to receive(:variants) do |_term, **opts|
      received = opts[:limit]
      []
    end
    ::Search.execute("zorbleflux bug")
    expect(received).to eq(1)
  end
end
