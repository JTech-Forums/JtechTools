# frozen_string_literal: true
# Jtech sub-plugin: smart search.
#
# Expands the user's search term with synonyms — WordNet (the rwordnet gem)
# for general English, plus a curated tech-jargon overlay shipped at
# config/dictionaries/smart_search_synonyms.yml, plus any site-specific
# groups from the smart_search_extra_synonyms setting — so that "js" finds
# posts that only say "javascript" and "k8s" finds "kubernetes". The
# original search runs first, and only when it returns fewer than
# `smart_search_minimum_results` posts do variant searches run and get
# merged in.
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

  # Layer the admin-editable synonym groups on top of the shipped dictionary.
  # Entries are comma-separated words ("|" is the list separator). Applied at
  # boot and re-applied whenever the setting changes.
  refresh_extra_synonyms =
    lambda do
      extras =
        SiteSetting
          .smart_search_extra_synonyms_map
          .map { |row| row.split(",").map(&:strip).reject(&:empty?) }
          .reject { |group| group.size < 2 }
      ::DiscourseSmartSearch::Synonyms.reload!(extras: extras)
    rescue StandardError => e
      Rails.logger.warn("[smart-search] extra synonyms reload failed: #{e.class}: #{e.message}")
    end

  refresh_extra_synonyms.call if SiteSetting.smart_search_extra_synonyms.present?

  on(:site_setting_changed) do |name, _old, _new|
    refresh_extra_synonyms.call if name.to_s == "smart_search_extra_synonyms"
  end
end
