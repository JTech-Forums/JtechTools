# frozen_string_literal: true

module DiscourseModCategories
  # Prevent whisper posts from ever landing in `post_search_data` (the
  # tsvector index Discourse's full-text search queries). If the row does
  # not exist, no ts_query can match it — so no non-audience viewer can
  # discover whisper text through search, and no `is:unseen` advanced
  # filter can shortcut around Guardian by hitting the index directly.
  #
  # This is the DB-level gate. Query-time filters (WhisperQueryFilter and
  # SearchWhisperFilter) are the belt-and-suspenders layer on top.
  #
  # Behavior:
  #   * On `SearchIndexer.index(post)` for a whisper post: skip the write
  #     AND delete any pre-existing row (defense against a race where the
  #     custom field is set slightly after the first index attempt).
  #   * On `SearchIndexer.index(post)` for a non-whisper post: pass through
  #     to super — normal indexing runs.
  #   * Non-Post inputs (Topic, Category, User…) pass through untouched.
  #
  # A post's whisper state is read from `post_custom_fields` directly rather
  # than `post.custom_fields` — the latter may lag behind the DB in some
  # code paths (post reloaded from cache, custom fields not preloaded).
  # A single indexed lookup keyed on (post_id, name) is cheap.
  #
  # rescue StandardError → fall back to `super` so a schema change to
  # `post_custom_fields` (or a NULL post argument) can never break search
  # indexing for public posts.
  module SearchIndexerExtension
    def index(obj, force: false)
      if whisper_post?(obj)
        ::PostSearchData.where(post_id: obj.id).delete_all
        return
      end
      super
    rescue StandardError => e
      ::Rails.logger.warn(
        "[jtech-tools] SearchIndexer whisper gate fell back: #{e.class}: #{e.message}",
      )
      super
    end

    private

    def whisper_post?(obj)
      return false unless defined?(::SiteSetting) && ::SiteSetting.mod_whisper_enabled
      return false unless obj.is_a?(::Post)
      return false unless obj.id

      ::PostCustomField.where(
        post_id: obj.id,
        name: DiscourseModCategories::POST_WHISPER_TARGETS_FIELD,
      ).exists?
    end
  end
end
