# frozen_string_literal: true

module ::DiscourseSmartSearch
  # Prepended onto ::Search. Runs the original term first, then — only
  # when the original returned fewer than `smart_search_minimum_results`
  # posts — runs each synonym-expanded variant and merges the new posts
  # into the base result set.
  #
  # FALLBACK CONTRACT:
  # The vanilla `super` runs FIRST and its result is captured in `base`
  # before any smart-search code runs. From that point on, every smart-
  # search code path — dictionary lookup, variant generation, inner
  # variant search, merge — is wrapped in `rescue StandardError` and on
  # any failure we return `base` (the vanilla result) unchanged. A
  # broken dictionary, a Postgres error on a variant query, a future
  # Discourse refactor of `Search#execute`, an exception in Synonyms.for,
  # a SiteSetting read failure — none of these can cause `Search.execute`
  # to raise. Search degrades to vanilla, never to broken.
  #
  # The only path that can still raise is the original `super` itself —
  # i.e. if vanilla Discourse search is broken, we cannot rescue that.
  # That's correct: smart-search isn't a circuit breaker for core
  # Discourse, only for its own expansion code.
  #
  # Recursion is prevented by setting `@opts[:smart_search_disable]`
  # when constructing the inner Search instances; the prepend rechecks
  # that flag and short-circuits, so the inner searches behave like
  # plain Discourse search.
  module SearchExtension
    def execute(readonly_mode: ::Discourse.readonly_mode?)
      base =
        begin
          super(readonly_mode: readonly_mode)
        rescue ArgumentError
          # Older Discourse versions used a positional or no-kwarg form
          # of Search#execute. Retry without the kwarg so the prepend
          # is forward-and-backward compatible.
          super()
        end

      return base unless smart_search_applies?
      return base if smart_search_disabled?

      begin
        threshold = ::SiteSetting.smart_search_minimum_results.to_i
        return base if base.posts.size >= threshold

        variants =
          ::DiscourseSmartSearch::QueryExpander.variants(
            @term,
            limit: ::SiteSetting.smart_search_variant_limit.to_i.clamp(1, 5),
          )
        return base if variants.empty?

        variants.each { |alt_term| merge_variant(base, alt_term, readonly_mode) }
        base
      rescue StandardError => e
        ::Rails.logger.warn(
          "[smart-search] expansion failed for term=#{@term.inspect}: " \
            "#{e.class}: #{e.message}",
        )
        base
      end
    end

    private

    def smart_search_applies?
      return false unless defined?(::SiteSetting)
      return false unless ::SiteSetting.smart_search_enabled
      return false if @term.blank?
      true
    end

    def smart_search_disabled?
      @opts.is_a?(Hash) && @opts[:smart_search_disable]
    end

    # Runs a fresh Search with the expanded term, marked so it does not
    # itself re-enter smart-search (infinite recursion guard). The new
    # search inherits the original `@opts` so guardian, search context,
    # type filters, etc. are preserved.
    def merge_variant(base, alt_term, readonly_mode)
      inner_opts = (@opts || {}).merge(smart_search_disable: true)
      alt = self.class.new(alt_term, inner_opts)
      alt_result =
        begin
          alt.execute(readonly_mode: readonly_mode)
        rescue ArgumentError
          alt.execute
        end
      merge_into!(base, alt_result)
    end

    def merge_into!(base, alt)
      return unless base && alt
      existing_ids = base.posts.map(&:id).to_set
      alt.posts.each do |post|
        next if existing_ids.include?(post.id)
        base.posts << post
        existing_ids << post.id
      end
    rescue StandardError => e
      ::Rails.logger.warn("[smart-search] merge failed: #{e.class}: #{e.message}")
    end
  end
end
