# frozen_string_literal: true

module ::DiscourseSmartSearch
  # Given a raw search term, returns up to `limit` alternative term
  # strings produced by substituting each content word with its top
  # synonym from the dictionary. The original term is NOT included in
  # the returned list — callers run the original separately and merge.
  #
  # Operator tokens (`category:foo`, `tags:bar`, `@username`, `#tag`,
  # `in:title`, etc.) are preserved verbatim — only bare content words
  # get expanded. This keeps Discourse's advanced search syntax working
  # untouched when smart-search is on.
  module QueryExpander
    # Common stop-words that shouldn't trigger a synonym variant.
    # Substituting "the" or "and" would produce nonsense variants.
    STOP_WORDS = %w[
      a
      an
      the
      and
      or
      but
      if
      then
      else
      when
      while
      of
      in
      on
      at
      to
      from
      by
      for
      with
      i
      you
      he
      she
      it
      we
      they
      me
      him
      her
      us
      them
      my
      your
      his
      hers
      its
      our
      their
      is
      are
      was
      were
      be
      been
      being
      am
      do
      does
      did
      doing
      have
      has
      had
      having
      not
      no
      yes
      so
      very
      just
      only
      also
      can
      could
      should
      would
      will
      shall
      may
      might
      this
      that
      these
      those
      there
      here
      what
      which
      who
      whom
      whose
      how
      why
      where
    ].freeze

    # A token is "expandable" if it's all letters/digits/hyphens — i.e.
    # NOT a Discourse advanced-search operator like `category:x`, NOT a
    # mention `@user`, NOT a tag ref `#tag`, NOT a quoted phrase.
    OPERATOR_PREFIXES = %w[@ # +].freeze

    class << self
      # Returns up to `limit` alternative term strings, never including
      # the original. Empty array when no content word has any synonym.
      def variants(term, limit: 2)
        return [] if term.blank?

        tokens = tokenize(term)
        return [] if tokens.empty?

        # For each token position, collect the synonyms (excluding the
        # original word). Tokens with no synonyms contribute nothing.
        substitutions =
          tokens
            .each_with_index
            .map do |tok, idx|
              next nil unless expandable?(tok)
              syns = ::DiscourseSmartSearch::Synonyms.for(tok.downcase) - [tok.downcase]
              next nil if syns.empty?
              [idx, syns]
            end
            .compact

        return [] if substitutions.empty?

        # Variant 1: replace EVERY expandable token with its first
        # synonym. One alternate query that maximally substitutes.
        # Variant 2: replace only the FIRST expandable token. Useful
        # when the user typed one ambiguous keyword and the surrounding
        # words are unique to a specific topic.
        # Cap at `limit` to bound the number of extra search queries.
        results = []

        full_swap = tokens.dup
        substitutions.each { |idx, syns| full_swap[idx] = syns.first }
        results << full_swap.join(" ") if full_swap.join(" ") != term

        first_idx, first_syns = substitutions.first
        first_only = tokens.dup
        first_only[first_idx] = first_syns.first
        first_joined = first_only.join(" ")
        results << first_joined if first_joined != term && !results.include?(first_joined)

        results.first(limit)
      end

      private

      def tokenize(term)
        # Keep quoted phrases intact so `"exact match"` searches don't
        # get expanded mid-phrase. Naive split-on-whitespace is enough
        # for our purposes — we treat each unquoted run of non-space
        # characters as one token.
        term.to_s.scan(/"[^"]*"|\S+/)
      end

      def expandable?(token)
        return false if token.blank?
        return false if token.start_with?(*OPERATOR_PREFIXES)
        return false if token.include?(":") # category:foo, tags:bar, in:title, etc.
        return false if token.start_with?('"') && token.end_with?('"')
        return false if token.length < 2 # single letters never carry meaning
        downcased = token.downcase
        return false if STOP_WORDS.include?(downcased)
        true
      end
    end
  end
end
