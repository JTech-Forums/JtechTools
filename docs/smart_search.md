# Smart search

When a search finds too little, smart search retries it with synonyms and adds what the retries find. "js" finds posts that only say "javascript"; "k8s" finds "kubernetes". It runs in-process: no API keys, no external service.

## How a search runs

1. Core's search runs as normal. Its result is kept whatever happens next.
2. Smart search steps in only if all of these hold:
   - `smart_search_enabled` is on;
   - this is the first page;
   - the search found fewer than `smart_search_minimum_results` posts (default 5);
   - there's no further page of results.
3. `QueryExpander` builds up to `smart_search_variant_limit` (1–2) alternate queries from what the user typed:
   - one with every content word swapped for its first synonym;
   - one with only the first content word swapped.

   Operators (`#category`, `tags:`, `@user`, `in:title`, `order:`…), quoted phrases, short words and stop words are left as they are.
4. Each alternate query runs as its own `Search`:
   - with the same options, so the same guardian, context, type filter and permissions;
   - restricted to posts;
   - not written to the search log and not firing `:user_search`.

   New posts are added through `GroupedSearchResults#add`, which keeps the page size. A topic already listed isn't added again (except when searching inside one topic).
5. Any error in steps 2–4 is logged and the core result is returned unchanged.

## Where synonyms come from

`DiscourseSmartSearch::Synonyms.for(word)` returns the word followed by its synonyms. It checks two sources in this order:

1. **The dictionary**, which merges two lists:
   - `config/dictionaries/smart_search_synonyms.yml`: abbreviations, product names and forum shorthand that WordNet doesn't know;
   - the site's own groups in `smart_search_extra_synonyms`: one group per entry, comma-separated words, e.g. `laptop,notebook`.

   In each group, the first other word is the one offered, so list the clearest term first. Leave out everyday English words ("go", "next", "rest"): every search containing one would be retried as jargon.
2. **WordNet** (the `rwordnet` gem, ~117K English words) for everything else. Multi-word entries are skipped.

Changes to `smart_search_extra_synonyms` apply on the next search, in every process and per site on a multisite. Dictionary file edits need a restart.

## Cost

- A search that finds enough costs nothing extra.
- Otherwise it costs up to two more post searches.
- WordNet's index takes about 40MB and half a second to build. In production it's loaded at boot, before the web server forks, so the workers share it.

## Checking it

```ruby
DiscourseSmartSearch::Synonyms.for("k8s")            # => ["k8s", "kubernetes"]
DiscourseSmartSearch::QueryExpander.variants("k8s ingress #hosting")
DiscourseSmartSearch::Synonyms.wordnet_available?
```

Specs: `spec/lib/discourse_smart_search/` (dictionary and expander) and `spec/requests/smart_search_spec.rb`. The request spec runs real searches, covering:

- filters kept on the retry;
- hidden posts not shown;
- one post per topic;
- first page only;
- the search log;
- the fallback on errors.
