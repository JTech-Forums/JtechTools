# frozen_string_literal: true

require "rails_helper"

# Regression coverage for the whisper search leak
# (forums.jtechforums.org/t/whispers-being-indexed-in-search/7800): whisper
# text was reachable through full-text search by non-audience users, because
# Discourse indexes every post into `post_search_data` and runs `ts_query`
# against it BEFORE any per-user visibility check. The `is:unseen` advanced
# filter widened the same hole.
#
# Fix under test (DB-level primary, per the reporter's own suggestion that
# "whispers should not be indexed"):
#   1. SearchIndexerExtension keeps whisper rows OUT of `post_search_data`
#      entirely — so no tsquery can match them, for anyone. A whisper is
#      simply not full-text-searchable; the audience still reads it in the
#      topic stream, they just can't discover it via /search.
#   2. SearchExtension post-filters any whisper row that lingers (index-gate
#      race, backfill pending) so a stranger still can't see it, while the
#      audience can — the only path where a whisper surfaces in search.
RSpec.describe "Whisper search leak" do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:target, :user)
  fab!(:stranger, :user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: author, raw: "ordinary opening post body") }
  fab!(:whisper_post) do
    Fabricate(:post, topic: topic, user: author, raw: "the secret whisper word Boooo lives here")
  end

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.auto_silence_fast_typers_on_first_post = false

    SearchIndexer.enable
    SearchIndexer.index(op, force: true)
    SearchIndexer.index(topic, force: true)
  end

  after { SearchIndexer.disable }

  def mark_whisper!(post = whisper_post)
    post.custom_fields[targets_field] = [target.id]
    post.save_custom_fields(true)
    post.reload
  end

  def search_post_ids(term, viewer)
    guardian = viewer ? Guardian.new(viewer) : Guardian.new
    Search.new(term, guardian: guardian).execute.posts.map(&:id)
  end

  describe "SearchIndexer gate" do
    it "never writes a post_search_data row for a whisper" do
      mark_whisper!
      SearchIndexer.index(whisper_post, force: true)
      expect(PostSearchData.where(post_id: whisper_post.id)).not_to exist
    end

    it "deletes a pre-existing row when a public post becomes a whisper" do
      SearchIndexer.index(whisper_post, force: true)
      expect(PostSearchData.where(post_id: whisper_post.id)).to exist

      mark_whisper!
      SearchIndexer.index(whisper_post, force: true)
      expect(PostSearchData.where(post_id: whisper_post.id)).not_to exist
    end

    it "still indexes ordinary public posts" do
      SearchIndexer.index(whisper_post, force: true)
      expect(PostSearchData.where(post_id: whisper_post.id)).to exist
    end
  end

  describe "search results (whisper deindexed)" do
    before do
      mark_whisper!
      SearchIndexer.index(whisper_post, force: true) # gate deletes the row
    end

    it "is unsearchable by a stranger" do
      expect(search_post_ids("Boooo", stranger)).not_to include(whisper_post.id)
    end

    it "is unsearchable by an anonymous viewer" do
      expect(search_post_ids("Boooo", nil)).not_to include(whisper_post.id)
    end

    # A whisper is removed from the index outright, so even the audience
    # can't full-text-search it. They still read it in the topic stream —
    # this only removes the /search discovery path.
    it "is unsearchable even by a target, because the row is gone" do
      expect(search_post_ids("Boooo", target)).not_to include(whisper_post.id)
    end

    it "is unsearchable even by staff" do
      expect(search_post_ids("Boooo", admin)).not_to include(whisper_post.id)
    end
  end

  # Belt-and-suspenders: a REAL post_search_data row lingers because the post
  # was indexed while public, then became a whisper without a re-index. The
  # query-time filter must still strip it for a stranger while letting the
  # audience through.
  describe "query-time filter on a lingering row" do
    fab!(:lingering) do
      Fabricate(:post, topic: topic, user: author, raw: "lingering whisper term Zzxq stays put")
    end

    before do
      SearchIndexer.index(lingering, force: true) # real tsvector row, still public
      mark_whisper!(lingering) # marked whisper via custom field, NOT re-indexed
    end

    it "keeps the real row (no re-index was triggered)" do
      expect(PostSearchData.where(post_id: lingering.id)).to exist
    end

    it "strips the lingering whisper from a stranger" do
      expect(search_post_ids("Zzxq", stranger)).not_to include(lingering.id)
    end

    it "strips the lingering whisper from an anonymous viewer" do
      expect(search_post_ids("Zzxq", nil)).not_to include(lingering.id)
    end

    it "still surfaces the lingering whisper to the audience" do
      expect(search_post_ids("Zzxq", target)).to include(lingering.id)
    end

    it "still surfaces the lingering whisper to staff" do
      expect(search_post_ids("Zzxq", admin)).to include(lingering.id)
    end
  end

  describe "convert to public re-indexes" do
    it "makes a disarmed whisper discoverable again" do
      mark_whisper!
      SearchIndexer.index(whisper_post, force: true)
      expect(search_post_ids("Boooo", stranger)).not_to include(whisper_post.id)

      PostCustomField.where(post_id: whisper_post.id, name: targets_field).destroy_all
      whisper_post.reload
      DiscourseEvent.trigger(:mod_whisper_state_changed, whisper_post, false)

      expect(PostSearchData.where(post_id: whisper_post.id)).to exist
      expect(search_post_ids("Boooo", stranger)).to include(whisper_post.id)
    end
  end
end
