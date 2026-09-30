# frozen_string_literal: true

module ::DiscourseSmartSearch
  # Prepended onto ::Search. Runs the search as normal; when the first page
  # comes back with fewer than `smart_search_minimum_results` posts (and no
  # further pages), it retries with synonym-swapped terms and adds the new
  # posts to the same result set.
  #
  # FALLBACK CONTRACT: core's search runs first and its result is kept. Every
  # smart-search step after that is rescued, and on any failure the core
  # result is returned unchanged — search degrades to vanilla, never to
  # broken. Only core's own search can still raise.
  #
  # The retries are ordinary Search instances with the same options (same
  # guardian, context and type filter, so they can never see more than the
  # original), marked with `smart_search_disable` so they don't expand
  # again, aren't written to the search log and don't fire :user_search.
  module SearchExtension
    def execute(readonly_mode: ::Discourse.readonly_mode?)
      base = super
      return base unless smart_search_applies?

      begin
        return base if base.posts.size >= ::SiteSetting.smart_search_minimum_results.to_i
        return base if base.more_full_page_results || base.more_posts

        # clean_term still carries the advanced-search operators
        # (category:, tags:, @user, in:title, order:…), which QueryExpander
        # passes through untouched; @term has them stripped.
        variants =
          ::DiscourseSmartSearch::QueryExpander.variants(
            clean_term,
            limit: ::SiteSetting.smart_search_variant_limit.to_i.clamp(1, 2),
          )
        variants.each { |alt_term| merge_variant(base, alt_term, readonly_mode) }
        base
      rescue StandardError => e
        ::Rails.logger.warn(
          "[smart-search] expansion failed for term=#{clean_term.inspect}: " \
            "#{e.class}: #{e.message}",
        )
        base
      end
    end

    private

    def log_query?(readonly_mode)
      return false if smart_search_disabled?
      super
    end

    def trigger_user_search_event(readonly_mode)
      return if smart_search_disabled?
      super
    end

    # Only the first page: later pages of a query with enough results never
    # need it, and merging into page N would repeat or skip results.
    def smart_search_applies?
      ::SiteSetting.jtech_enabled && ::SiteSetting.smart_search_enabled &&
        !smart_search_disabled? && clean_term.present? && @page.to_i <= 1
    end

    def smart_search_disabled?
      @opts.is_a?(Hash) && @opts[:smart_search_disable]
    end

    def merge_variant(base, alt_term, readonly_mode)
      inner_opts = @opts.merge(smart_search_disable: true)
      # The header search also looks up users, categories and tags; only
      # posts are merged, so the retry skips the rest.
      inner_opts[:type_filter] ||= "topic"
      merge_into!(base, self.class.new(alt_term, inner_opts).execute(readonly_mode: readonly_mode))
    end

    # Results are one post per topic except when searching inside a topic,
    # so a topic already listed isn't added again through another post.
    def merge_into!(base, alt)
      return unless base && alt
      per_topic = !@search_context.is_a?(::Topic)
      post_ids = base.posts.map(&:id).to_set
      topic_ids = base.posts.map(&:topic_id).to_set

      alt.posts.each do |post|
        next if post_ids.include?(post.id)
        next if per_topic && topic_ids.include?(post.topic_id)
        # GroupedSearchResults#add enforces the page size and sets the
        # "more" flags.
        base.add(post)
        post_ids << post.id
        topic_ids << post.topic_id
      end
    end
  end
end
