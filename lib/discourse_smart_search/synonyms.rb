# frozen_string_literal: true

module ::DiscourseSmartSearch
  # Synonym lookup with two backends, consulted in order:
  #
  #   1. YAML overlay (`config/dictionaries/smart_search_synonyms.yml`)
  #      — small, hand-curated tech-jargon dictionary. Catches the
  #      domain-specific terms WordNet doesn't know (js, k8s, postgres,
  #      docker, etc.). ~30 entries, lowercase ASCII, symmetric groups.
  #
  #   2. WordNet via the `wordnet` + `wordnet-defaultdb` gems — bundled
  #      English lexical DB with ~117K word forms. Covers general
  #      English (bug ↔ defect ↔ glitch, fast ↔ quick ↔ rapid, …) so
  #      we don't have to hand-curate it.
  #
  # Either backend's failure is non-fatal: a missing gem, a missing/
  # malformed YAML, or a WordNet lookup raise all degrade silently to
  # "just the input word" — search then behaves like vanilla Discourse.
  # The fallback contract documented at the top of
  # `lib/discourse_smart_search/search_extension.rb` depends on it.
  #
  # An in-memory LRU cache (default 2000 entries) protects against
  # repeated lookups during a single Search execution chain.
  module Synonyms
    DEFAULT_PATH =
      ::File.expand_path("../../config/dictionaries/smart_search_synonyms.yml", __dir__)

    CACHE_LIMIT = 2000

    # Hard cap on synonyms returned per lookup. Prevents a runaway
    # WordNet expansion (a polysemous word like "set" has 50+ synonyms
    # across all senses) from blowing up variant generation.
    MAX_SYNONYMS_PER_WORD = 20

    class << self
      # Returns the synonym set for `word`, including the word itself.
      # Empty array for blank input; `[word]` when no synonyms exist.
      def for(word)
        return [] if word.blank?
        key = word.to_s.downcase.strip
        return [] if key.empty?

        cached = cache[key]
        return cached if cached

        result = lookup_uncached(key)
        cache_set(key, result)
        result
      end

      # Forces a fresh load of the YAML overlay + clears the cache.
      # Used by specs; in production the dictionary loads once at boot.
      def reload!(path: DEFAULT_PATH, extras: nil)
        groups = load_groups(path)
        groups.concat(extras) if extras.is_a?(Array)
        @overlay_index = build_index(groups)
        @cache = {}
        nil
      end

      # Exposed for tests; the overlay alone (without WordNet) so a
      # spec can assert the curated entries directly.
      def overlay_index
        @overlay_index ||= build_index(load_groups(DEFAULT_PATH))
      end

      # True when the WordNet backend is available + lexicon loaded.
      # Memoized after the first call.
      def wordnet_available?
        return @wordnet_available unless @wordnet_available.nil?
        @wordnet_available =
          begin
            require "wordnet"
            require "wordnet-defaultdb"
            @lexicon = ::WordNet::Lexicon.new
            # Touch the DB once to surface any startup failure here
            # rather than on the first user search.
            @lexicon.find_words("test")
            true
          rescue StandardError, ::LoadError => e
            ::Rails.logger.warn(
              "[smart-search] WordNet backend unavailable: #{e.class}: #{e.message}",
            )
            false
          end
      end

      private

      def lookup_uncached(key)
        # 1. Overlay (curated tech jargon).
        hit = overlay_index[key]
        return hit if hit

        # 2. WordNet (general English).
        wn = wordnet_synonyms_for(key)
        return wn if wn.size > 1

        # 3. Default — just the word itself.
        [key].freeze
      end

      def wordnet_synonyms_for(key)
        return [] unless wordnet_available?

        synonyms = Set.new([key])
        @lexicon
          .find_words(key)
          .each do |word_rec|
            word_rec.synsets.each do |synset|
              synset.words.each do |sw|
                lemma = sw.lemma.to_s.gsub("_", " ").downcase.strip
                synonyms << lemma if lemma.length >= 2 && lemma.length <= 60
                break if synonyms.size >= MAX_SYNONYMS_PER_WORD
              end
              break if synonyms.size >= MAX_SYNONYMS_PER_WORD
            end
            break if synonyms.size >= MAX_SYNONYMS_PER_WORD
          end
        synonyms.to_a.sort.freeze
      rescue StandardError => e
        ::Rails.logger.warn(
          "[smart-search] WordNet lookup failed for #{key.inspect}: " \
            "#{e.class}: #{e.message}",
        )
        []
      end

      # Lazily-allocated LRU cache. Using Hash's insertion-order
      # iteration as the LRU primitive — `cache.shift` removes the
      # oldest entry, `cache[key] = value` re-orders on overwrite.
      def cache
        @cache ||= {}
      end

      def cache_set(key, value)
        c = cache
        c.delete(key) if c.key?(key)
        c[key] = value
        c.shift while c.size > CACHE_LIMIT
        value
      end

      def load_groups(path)
        return [] unless ::File.exist?(path)
        raw = ::YAML.safe_load(::File.read(path)) || []
        return [] unless raw.is_a?(Array)
        raw.select { |g| g.is_a?(Array) && g.size >= 2 }
      rescue StandardError => e
        ::Rails.logger.warn(
          "[smart-search] dictionary load failed for #{path}: #{e.class}: #{e.message}",
        )
        []
      end

      def build_index(groups)
        table = {}
        groups.each do |group|
          normalized = group.map { |w| w.to_s.downcase.strip }.reject(&:empty?).uniq
          next if normalized.size < 2
          set = normalized.sort.freeze
          normalized.each { |w| (table[w] ||= []).concat(set) }
        end
        table.each_with_object({}) { |(k, v), out| out[k] = v.uniq.sort.freeze }.freeze
      end
    end
  end
end
