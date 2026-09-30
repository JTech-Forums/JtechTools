# frozen_string_literal: true
# Jtech sub-plugin: smart search.
#
# When a search finds too little, retry it with synonyms — WordNet (the
# rwordnet gem) for general English, a curated tech-jargon overlay
# (config/dictionaries/smart_search_synonyms.yml) and the site's own groups
# (smart_search_extra_synonyms) — so "js" finds posts that only say
# "javascript". See DiscourseSmartSearch::SearchExtension.
#
# No external services: everything is in-process Ruby, and every step is
# rescued back to the plain search result.

require_relative "../lib/discourse_smart_search/synonyms"
require_relative "../lib/discourse_smart_search/query_expander"
require_relative "../lib/discourse_smart_search/search_extension"

after_initialize do
  reloadable_patch { ::Search.prepend(::DiscourseSmartSearch::SearchExtension) }

  # WordNet's index takes ~40MB and half a second to load. Loading it before
  # the web server forks lets every worker share one copy instead of each
  # building its own on its first search.
  if Rails.env.production? && SiteSetting.jtech_enabled && SiteSetting.smart_search_enabled
    DiscourseSmartSearch::Synonyms.wordnet_available?
  end
end
