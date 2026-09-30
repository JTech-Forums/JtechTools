# Smart search

When a search finds too little, smart search retries it with synonyms and adds what it finds. "js" finds posts that only say "javascript"; "k8s" finds "kubernetes". It runs in-process, with no API keys or external service.

- It only steps in on the first page of results, when there are fewer than `smart_search_minimum_results` posts and no more pages.
- Retries keep the search's filters (`#category`, `tags:`, `@user`, `in:title`…) and permissions, and never show a post the searcher can't see.
- A topic isn't listed twice, and retries aren't written to the search log.
- Synonyms come from WordNet (general English), a short tech-jargon list shipped with the plugin, and your own groups in `smart_search_extra_synonyms`.

How it works in detail: [development/smart-search.md](../development/smart-search.md).

## Settings

Admin → Plugins → Jtech Tools → **Smart search**. The full text of each setting is shown next to it in the admin.

| Setting | Default | What it does |
| --- | --- | --- |
| `smart_search_enabled` | `false` | When a search returns few results, run it again with synonyms substituted and merge the extra hits in, so that "js" also finds posts that only say "javascript" and "k8s" finds "kubernetes". |
| `smart_search_minimum_results` | `5` | Synonym variants only run when the user's original search returned fewer than this many posts. |
| `smart_search_variant_limit` | `2` | How many synonym-substituted searches may run in addition to the user's original one. |
| `smart_search_extra_synonyms` | `(blank)` | Site-specific synonym groups added on top of the dictionary shipped with the plugin. |

[← All features](../README.md#features)
