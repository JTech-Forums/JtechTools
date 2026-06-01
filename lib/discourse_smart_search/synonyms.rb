# frozen_string_literal: true

module ::DiscourseSmartSearch
  # Loads the synonym dictionary once at boot and exposes a single
  # `for(word)` lookup that returns the symmetric synonym set for the
  # given word (including the word itself), or just `[word]` if the word
  # appears in no group.
  #
  # The dictionary lives in `config/dictionaries/smart_search_synonyms.yml`
  # and is reloaded by `Synonyms.reload!` (test helper). Custom admin-
  # uploaded dictionaries are merged on top via `merge_extras!`.
  module Synonyms
    DEFAULT_PATH =
      ::File.expand_path("../../config/dictionaries/smart_search_synonyms.yml", __dir__)

    class << self
      # Map of word -> sorted unique synonym set (including the word
      # itself). Frozen once built so concurrent readers can never see a
      # half-built table.
      def index
        @index ||= build_index(load_groups(DEFAULT_PATH))
      end

      # Returns the synonym set for `word`, or `[word]` if no entry.
      # Always returns the input word in the result so callers can use
      # the result as the canonical "all forms" list without an extra
      # union step.
      def for(word)
        return [] if word.blank?
        key = word.to_s.downcase.strip
        return [] if key.empty?

        hit = index[key]
        return [key] if hit.nil?
        hit
      end

      # Rebuild the in-memory index from disk + any extras. Specs call
      # this between examples to swap in test fixtures.
      def reload!(path: DEFAULT_PATH, extras: nil)
        groups = load_groups(path)
        groups.concat(extras) if extras.is_a?(Array)
        @index = build_index(groups)
      end

      private

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
        # Each word may appear in multiple groups (e.g. "behavior" in a
        # general English group AND an ABA-jargon group). Merge and
        # dedupe so the lookup returns one combined synonym set.
        table.each_with_object({}) { |(k, v), out| out[k] = v.uniq.sort.freeze }.freeze
      end
    end
  end
end
