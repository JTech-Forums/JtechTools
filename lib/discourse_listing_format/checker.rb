# frozen_string_literal: true

module ::DiscourseListingFormat
  # Says what's wrong with a post's text, as messages for the person
  # posting. An empty list means it may be saved.
  class Checker
    ALLOWED_SCHEMES = %w[mailto tel sms].freeze

    # A topic's address with a slug: /t/some-slug/32 or /t/some-slug/32/232.
    # The slug has to contain a non-digit, or /t/32/232 would read as 232.
    TOPIC_URL = %r{/t/(?:[^/?#]*[^\d/?#][^/?#]*/)?(\d+)}

    # Markdown that can sit around a field's name without changing it:
    # list bullets, headings, bold and italics.
    LEADING_MARKUP = /\A(?:\s*(?:[-*+]|\d+[.)]|#+)\s+)?/
    EMPHASIS = /[*_~]+/

    # Web addresses typed as plain text ("ebay.com/itm/123"), which the
    # forum doesn't turn into links but are still a way off the forum. Only
    # common endings, so "v2.0" or "node.js" aren't taken for one; the
    # lookbehind leaves email addresses alone.
    BARE_DOMAIN =
      %r{(?<![@\w.\-])((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+(?:com|net|org|co|io|me|us|uk|ca|il|biz|info|shop|store|app|ly|gl|to|link))(?![\w-])}i

    # Admins can paste a topic's address instead of its number.
    def self.topic_ids
      SiteSetting
        .listing_format_topics
        .to_s
        .split("|")
        .filter_map do |entry|
          entry = entry.strip
          id = entry.match?(/\A\d+\z/) ? entry : entry[TOPIC_URL, 1]
          id&.to_i
        end
        .uniq
    end

    def self.fields
      SiteSetting.listing_format_fields.to_s.split("|").map(&:strip).reject(&:empty?).uniq
    end

    # `previous` is the text before an edit, nil for a new post.
    def initialize(raw, previous: nil, topic_id: nil)
      @raw = raw.to_s
      @previous = previous
      @topic_id = topic_id
    end

    def problems
      [missing_fields_problem, links_problem].compact
    end

    def missing_fields
      missing = self.class.missing_fields_in(@raw)
      # An older post only has to keep the fields it already had.
      missing &= self.class.fields - self.class.missing_fields_in(@previous) if @previous
      missing
    end

    def outside_links
      links = outside_links_in(@raw)
      links -= outside_links_in(@previous) if @previous
      links
    end

    def self.missing_fields_in(raw)
      lines = strip_quotes(raw.to_s).lines.map { |line| line.sub(LEADING_MARKUP, "") }
      fields.reject do |field|
        pattern = /\A#{Regexp.escape(field)}\s*(?::|-|–|—)\s*(.*)\z/i
        lines.any? do |line|
          value = line.gsub(EMPHASIS, "").strip[pattern, 1]
          value.present?
        end
      end
    end

    # Quoted posts are someone else's words; their fields don't count.
    def self.strip_quotes(raw)
      text = raw.dup
      # Innermost first, so nested quotes come out whole.
      while text.sub!(%r{\[quote(?:=[^\]]*)?\](?:(?!\[quote).)*?\[/quote\]}im, "")
      end
      text.lines.reject { |line| line.lstrip.start_with?(">") }.join
    end

    private

    def missing_fields_problem
      missing = missing_fields
      return if missing.empty?

      I18n.t(
        "listing_format.errors.missing_fields",
        fields: missing.join(", "),
        example: "#{missing.first}: …",
      )
    end

    def links_problem
      return unless SiteSetting.listing_format_block_links
      links = outside_links
      return if links.empty?

      I18n.t("listing_format.errors.outside_links", links: links.first(3).join(", "))
    end

    # Links are read from the cooked post, so bare URLs, oneboxes,
    # [text](url) and <a> tags all count, quotes included.
    def outside_links_in(raw)
      return [] if raw.blank?
      fragment = Nokogiri::HTML5.fragment(PrettyText.cook(raw, topic_id: @topic_id))
      anchors = fragment.css("a")

      linked =
        anchors
          .map { |a| a["href"].to_s.strip }
          .reject { |href| allowed?(href) }
          .map { |href| display(href) }

      anchors.remove
      typed =
        fragment.text.scan(BARE_DOMAIN).flatten.map(&:downcase).reject { |host| forum_host?(host) }

      (linked + typed).uniq
    end

    def allowed?(href)
      return true if href.empty? || href.start_with?("#")
      return true if href.start_with?("/") && !href.start_with?("//")

      uri = URI.parse(href)
      return ALLOWED_SCHEMES.include?(uri.scheme.downcase) if uri.scheme && uri.host.nil?
      return true if uri.host.nil? && uri.scheme.nil?

      forum_host?(uri.host) || UrlHelper.is_local(href)
    rescue URI::Error
      false
    end

    def forum_host?(host)
      host = host.to_s.downcase
      [Discourse.current_hostname, GlobalSetting.hostname].compact.map(&:downcase).include?(host)
    end

    def display(href)
      URI.parse(href).host.presence || href
    rescue URI::Error
      href
    end
  end
end
