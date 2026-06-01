# Smart Search — how it works

Synonym query expansion for Discourse search. Lives in `sub_plugins/smart_search.rb` + `lib/discourse_smart_search/`. Default off; turn on with `smart_search_enabled`.

## The problem it solves

Vanilla Discourse search uses Postgres full-text matching. A user searching for `js` matches only posts containing literal `js` (plus stemmed variants). Posts that say `javascript` or `node` are invisible.

The previous attempt to fix this — Discourse AI's embedding-based semantic search — failed in production because every search query started returning 500 when the embedding backend was unreachable. **Smart Search is a deliberately lower-tech alternative** that can never have that failure mode.

## The 30-second mental model

1. User searches `js`.
2. Smart Search runs the user's original query unchanged. Vanilla result comes back with N posts.
3. If `N < smart_search_minimum_results` (default 5), it picks up to `smart_search_variant_limit` (default 2) alternate queries from a synonym dictionary — e.g. `javascript` — and runs them as fresh searches.
4. Results from the variant searches are merged into the vanilla result, deduplicated by post id.
5. User sees the union: posts that say `js` OR `javascript`.

Everything is in-process Ruby + Postgres. No external services, no API keys, no embedding model.

## The flow, in detail

```
User searches "js"
        │
        ▼
::Search.execute("js")             ← class method, calls new(...).execute
        │
        ▼
Search#execute (prepended by smart_search)
        │
        ├─ super(readonly_mode:)   ← VANILLA SEARCH RUNS FIRST
        │  └─ returns base.posts = [post_42, post_91]  (2 posts)
        │
        ├─ return base unless SiteSetting.smart_search_enabled
        ├─ return base if @opts[:smart_search_disable]   ← recursion guard
        │
        ├─ threshold = SiteSetting.smart_search_minimum_results.to_i  (5)
        ├─ return base if base.posts.size >= threshold   ← 2 < 5, continue
        │
        ├─ variants = QueryExpander.variants("js", limit: 2)
        │  └─ returns ["javascript"]   (one alt-term)
        │
        └─ for each variant:
            └─ merge_variant(base, "javascript", readonly_mode)
                ├─ inner_opts = @opts.merge(smart_search_disable: true)
                ├─ alt = Search.new("javascript", inner_opts).execute(...)
                │    └─ runs vanilla (recursion guard skips smart_search)
                │    └─ returns alt.posts = [post_7, post_91]
                ├─ existing_ids = {42, 91}
                ├─ alt.posts.each { append unless existing_ids.include?(p.id) }
                │    └─ post_7 is new → appended
                │    └─ post_91 already in base → skipped
                └─ base.posts = [post_42, post_91, post_7]
        │
        ▼
return base   ← 3 posts, including the "javascript" match vanilla missed
```

## Files

| File | Role |
| --- | --- |
| `sub_plugins/smart_search.rb` | Sub-plugin boot. After Discourse init, prepends `SearchExtension` onto `::Search`. |
| `lib/discourse_smart_search/search_extension.rb` | The prepend module. Overrides `Search#execute`. Contains the fallback contract (vanilla `super` runs first, every expansion path is rescued). |
| `lib/discourse_smart_search/query_expander.rb` | Given a term string, returns up to N alternative term strings via dictionary substitution. Preserves Discourse operators (`category:foo`, quoted phrases, `@mentions`, `#tags`), skips stop-words and single-character tokens. |
| `lib/discourse_smart_search/synonyms.rb` | Two-tier synonym lookup: tech-jargon YAML overlay first, then WordNet via the `wordnet` gem. Exposes `Synonyms.for(word)`. LRU-cached up to 2000 entries. |
| `config/dictionaries/smart_search_synonyms.yml` | The tech-jargon OVERLAY (only words WordNet doesn't know — `js ↔ javascript`, `k8s ↔ kubernetes`, etc.). |
| `plugin.rb` (top) | `gem` declarations for `wordnet` + `wordnet-defaultdb` — the ~20MB bundled English lexical DB. |

## Two backends — overlay + WordNet

`Synonyms.for(word)` checks two backends in order:

**1. YAML overlay** — `config/dictionaries/smart_search_synonyms.yml`. Small hand-curated dictionary (~70 entries) covering ONLY the words WordNet doesn't know: abbreviations, brand names, protocol initialisms, shop-floor jargon. Examples:

```yaml
# Languages — abbreviations ↔ full names
- [js, javascript, node, nodejs]
- [py, python, python3]
- [k8s, kubernetes, kube]

# Cloud providers
- [aws, amazonws]
- [gcp, googlecloud]

# Databases
- [pg, postgres, postgresql, psql]
```

**2. WordNet** — via the `wordnet` + `wordnet-defaultdb` gems. Bundled English lexical DB with ~117K word forms. Handles everything the overlay doesn't: `bug ↔ defect ↔ glitch ↔ fault`, `fast ↔ quick ↔ rapid ↔ speedy`, `problem ↔ issue ↔ trouble`, etc.

If neither backend finds the word, the lookup returns `[word]` (just the input). Search behaves like vanilla in that case.

**Why this split**: WordNet doesn't know `js` ↔ `javascript`. It also doesn't know `k8s` ↔ `kubernetes`. The overlay handles those. Everything else WordNet knows for free, so we don't curate it.

**Editing the overlay** (rules also in the YAML header):

- All entries MUST be lowercase ASCII. Lookup downcases at query time.
- Symmetric: every word in a row is a synonym of every other.
- Don't add general English here — WordNet covers it. Adding `[fast, quick, rapid]` would be dead weight.
- Don't group words that share spelling but not meaning.
- Verify with `DiscourseSmartSearch::Synonyms.for("your-word")` in a Rails console after restart.

**A word that appears in multiple overlay groups** has all those groups' synonyms merged into one set.

**Reloading**: the dictionary is read once at boot. To pick up edits, restart Discourse (or call `DiscourseSmartSearch::Synonyms.reload!` from a Rails console / test).

## Site settings

| Setting | Default | What it controls |
| --- | --- | --- |
| `smart_search_enabled` | `false` | Master switch. Off → behave exactly like vanilla. |
| `smart_search_minimum_results` | `5` | Variant queries only run when the vanilla result has FEWER posts than this. Raise this to be more aggressive (variants run more often); lower it to be conservative (variants only run when vanilla returns nothing). `0` disables variant expansion entirely (vanilla returns are always "enough"). |
| `smart_search_variant_limit` | `2` | Hard cap on the number of synonym-expanded variants run per search. Each variant is one extra SQL query. Range 1–5. |

## Fallback contract — what guarantees search can never break

The vanilla `super` call runs **FIRST** and its result is captured in `base` before any smart-search code executes. From that point on, every smart-search code path is wrapped in `rescue StandardError => e; Rails.logger.warn(...); base`.

That means:

- Dictionary YAML is malformed → caught, return vanilla.
- `Synonyms.for` raises (any reason) → caught, return vanilla.
- `QueryExpander.variants` raises → caught, return vanilla.
- Postgres errors on a variant query → caught, return vanilla.
- Future Discourse refactor changes `Search#execute`'s arity → `ArgumentError` rescue retries with no-kwarg form; if still broken, the vanilla path is unaffected.
- `SiteSetting` access raises → caught, return vanilla.

The **only** path that can still raise is the original `super` itself — i.e., if vanilla Discourse search is broken. That's correct: smart search isn't a circuit breaker for core Discourse, only for its own expansion code.

This is verified by request specs in `spec/requests/smart_search_spec.rb`:

```
it "does not raise when QueryExpander raises"
it "does not raise when Synonyms.for raises"
it "does not raise when an inner variant Search.new raises"
```

Each injects a failure into one layer and asserts `Search.execute` still returns a usable result.

## What smart search DOESN'T do

- **Stemming/morphology**: vanilla Discourse already does this (running ↔ run). Smart Search doesn't touch the tsvector pipeline.
- **Concept matching**: it can't bridge `slow server` ↔ `latency issue` unless the overlay or WordNet relates those tokens. WordNet's word-level synsets are sense-aware but not phrase-aware.
- **Cross-language search**: WordNet is English-only.
- **Typo tolerance**: Postgres `pg_trgm` is the layer for that. Smart search doesn't fuzzy-match on character similarity.

WordNet gives smart search ~117K English words "for free" — meaning recall is much higher than a pure hand-curated list. Tech jargon is the only category that needs hand-curation, and the YAML overlay handles ~70 of those.

## How variant generation works

For input `"js bug"`:

1. Tokenize → `["js", "bug"]`. Quoted phrases stay intact: `"some phrase"` is one token. Operator tokens (`category:foo`, `tags:bar`, `in:title`, `@user`, `#tag`) are preserved verbatim and skipped. Stop-words (`the`, `and`, `for`, etc.) and single-character tokens are skipped.
2. For each expandable token, look up synonyms via `Synonyms.for`:
   - `js` → `["js", "javascript", "node", "nodejs"]`
   - `bug` → `["bug", "error", "fault", "issue", "problem"]`
3. Generate up to two variant strings:
   - **Full swap**: replace every expandable token with its first synonym → `"javascript error"`.
   - **First-only swap**: replace just the first expandable token → `"javascript bug"`.
4. Variants identical to the original are dropped. The original itself is never included (it ran via `super` already).

The order — full-swap first, first-only second — is deliberate: full-swap maximizes recall when the user's whole query is jargon; first-only is a safety net when only one word is ambiguous.

## Performance

- Overlay load: ~5ms at boot. Map of ~70 head-words.
- WordNet load: ~50ms on first lookup (lexicon construction + first DB hit). Subsequent lookups are ~1–3ms each, served from SQLite.
- Cache: LRU bounded at 2000 entries. After the cache warms, every repeat lookup is sub-microsecond.
- Variant generation: O(words-in-query). For a typical 2–3 word search after cache warm-up, sub-millisecond.
- Variant execution: each variant is one full `Search.new(...).execute(...)` = one Postgres tsvector query. Bounded by `smart_search_variant_limit` (default 2), so the worst-case cost is 3 SQL queries (1 original + 2 variants) instead of 1.
- Merge: O(base.posts + alt.posts) per variant. Microseconds.

If you have a particularly heavy `/search` page and want to suppress variant overhead, raise `smart_search_minimum_results` (so vanilla "enough" results short-circuits more often).

## Adding new synonyms — recipe

1. Edit `config/dictionaries/smart_search_synonyms.yml`.
2. Add a row in the right section (general English, hardware, OS, language, web, devops, database, security, tools, formats, networking). Lowercase, symmetric, no spelling-collision-but-meaning-difference pairs.
3. Restart Discourse (or just touch `plugin.rb` and let dev-mode reload pick it up).
4. Spot-check: `Search.execute("your-new-word")` should return posts containing the synonym.

## Diagnostic

To see if smart search fired and what it did for a given query, check the Rails log for `[smart-search]` warnings. The only warnings produced are from the fallback rescue blocks — i.e., they only appear when something went wrong and search degraded to vanilla. Silence in the log = the happy path ran.

To test interactively in a Rails console:

```ruby
# Overlay hit (tech jargon):
DiscourseSmartSearch::Synonyms.for("js")
# => ["javascript", "js", "node", "nodejs"]

# WordNet hit (general English):
DiscourseSmartSearch::Synonyms.for("bug")
# => ["bug", "defect", "fault", "glitch", "hemipteran", "insect", ...]
# (WordNet's "bug" has multiple senses — insect, microorganism, defect,
# wiretap — and the lookup merges all of them, capped at
# MAX_SYNONYMS_PER_WORD = 20)

# Unknown word — returns just the input:
DiscourseSmartSearch::Synonyms.for("xyzzyplotch")
# => ["xyzzyplotch"]

# Is the WordNet backend live?
DiscourseSmartSearch::Synonyms.wordnet_available?
# => true   (false in environments where the gem failed to load)

DiscourseSmartSearch::QueryExpander.variants("js bug", limit: 2)
# => ["javascript defect", "javascript bug"]

Search.execute("js").posts.map(&:id)
# => [42, 91, 7]   (with smart search, includes posts via "javascript")
```
