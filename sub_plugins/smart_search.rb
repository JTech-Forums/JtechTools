# frozen_string_literal: true
# Jtech sub-plugin: smart search.
#
# Expands the user's search term with synonyms from a built-in dictionary
# (general English + ABA-domain jargon) so that "kid" finds posts that
# only say "child", "tantrum" finds "meltdown", "SIB" finds posts that
# spell out "self-injury", etc. The original search runs first, and only
# when it returns fewer than `smart_search_minimum_results` posts do
# variant searches run and get merged in.
#
# Reliability constraints (the previous semantic-search attempt 500'd
# every query; that must not recur):
#   * No external services, no API calls, no embedding models — all
#     synonym work is in-process Ruby + a YAML dictionary read once at
#     boot.
#   * Every code path that touches search is wrapped in rescue
#     StandardError → log + fall back to vanilla Discourse search.
#     A broken dictionary, a Postgres error on a variant query, or a
#     future Discourse refactor cannot break the user's search.
#   * Variant queries inherit the original `@opts` (guardian, filters,
#     context) so permissions are never widened.

require_relative "../lib/discourse_smart_search/synonyms"
require_relative "../lib/discourse_smart_search/query_expander"
require_relative "../lib/discourse_smart_search/search_extension"

after_initialize do
  reloadable_patch do
    ::Search.prepend(::DiscourseSmartSearch::SearchExtension) if defined?(::Search)
  end
end
