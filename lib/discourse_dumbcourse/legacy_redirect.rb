# frozen_string_literal: true

module DiscourseDumbcourse
  # Sends browsers that can't run the full forum to the matching Dumbcourse
  # page, instead of a page that renders as garbage. Also used for anyone
  # who chose "Open forum links here" in Dumbcourse (a cookie on their
  # phone), so links in emails and notifications open in the app they use.
  #
  # Only plain page loads (GET, HTML, not XHR, not API) of pages Dumbcourse
  # has an equivalent for are redirected, and never for search engines.
  module LegacyRedirect
    PREFER_COOKIE = "dumbcourse_prefer"

    # Browsers that can't run modern Discourse. Conservative on purpose.
    LEGACY_UA = [
      /KAIOS/i,
      /Opera Mini/i,
      /\bMSIE \d/,
      %r{Trident/},
      %r{\bPresto/},
      %r{UCBrowser/[0-9]\.},
    ].freeze
    CHROME_MIN = 80
    FIREFOX_MIN = 78

    def self.legacy_browser?(user_agent)
      ua = user_agent.to_s
      return false if ua.blank?
      return true if LEGACY_UA.any? { |re| ua.match?(re) }
      if (m = ua.match(%r{(?:Chrome|CriOS)/(\d+)}))
        return m[1].to_i < CHROME_MIN
      end
      if (m = ua.match(%r{Firefox/(\d+)}))
        return m[1].to_i < FIREFOX_MIN
      end
      # Old Android stock browser (no Chrome token).
      return true if ua.match?(/Android [1-4]\./) && !ua.include?("Chrome")
      CrawlerDetection.respond_to?(:show_browser_update?) &&
        CrawlerDetection.show_browser_update?(ua)
    end

    TOKEN = /[A-Za-z0-9_\-]+/

    # The Dumbcourse path for a forum path, or nil when there is none.
    def self.target_for(path, query)
      q = query.to_s
      mapped =
        case path
        # Links from emails first: /u/password-reset/… is not a profile.
        when %r{\A/session/email-login/(#{TOKEN})/?\z}o
          "/email-login/#{$1}"
        when %r{\A/u/password-reset/(#{TOKEN})/?\z}o
          "/password-reset/#{$1}"
        when %r{\A/u/activate-account/(#{TOKEN})/?\z}o
          "/activate-account/#{$1}"
        when "", "/"
          "/"
        when %r{\A/(latest|new|unread|top|hot|categories)/?\z}
          "/#{$1}"
        when %r{\A/(t|c|tag)/.+}
          path
        when %r{\A/u/([^/]+)/preferences(/.*)?\z}
          "/preferences"
        when %r{\A/u/([^/]+)/(activity/)?bookmarks/?\z}, %r{\A/my/(activity/)?bookmarks/?\z}
          "/bookmarks"
        when %r{\A/u/([^/]+)/messages(/.*)?\z}, %r{\A/my/messages(/.*)?\z}
          "/messages"
        when %r{\A/u/([^/]+)/notifications(/.*)?\z}, %r{\A/my/notifications(/.*)?\z},
             %r{\A/notifications/?\z}
          "/notifications"
        when %r{\A/u/(#{TOKEN})/?(summary|activity)?(/.*)?\z}o
          "/u/#{$1}"
        when "/search"
          term = Rack::Utils.parse_query(q)["q"].to_s
          return "/search" + (term.present? ? "?#{{ q: term }.to_query}" : "")
        when "/login"
          "/login"
        when "/signup"
          "/signup"
        when "/password-reset"
          "/password-reset"
        when "/reqpm"
          "/contacts"
        end
      return nil if mapped.nil?
      keep = Rack::Utils.parse_query(q).slice("page", "period", "tab", "filter")
      mapped + (keep.present? && !mapped.include?("?") ? "?#{keep.to_query}" : "")
    end

    def self.redirect_for(request, cookies)
      return nil unless DiscourseDumbcourse.enabled?
      return nil unless request.get? && !request.xhr?
      return nil unless request.format&.html?
      return nil if request.params[:api_key].present? || request.headers["HTTP_API_KEY"].present?
      preference = cookies[PREFER_COOKIE]
      return nil if preference == "0"
      ua = request.user_agent.to_s
      return nil if CrawlerDetection.crawler?(ua, request.headers["HTTP_VIA"])
      wanted =
        preference == "1" ||
          (SiteSetting.dumbcourse_redirect_legacy_browsers && legacy_browser?(ua))
      return nil unless wanted

      path = request.path.to_s
      base = Discourse.base_path.to_s
      path = path.delete_prefix(base) if base.present?
      app = DiscourseDumbcourse.base_path_with_slash
      return nil if path == app || path.start_with?("#{app}/")
      target = target_for(path, request.query_string)
      target && "#{base}#{app}#{target == "/" ? "" : target}"
    end

    # Mixed into ApplicationController.
    module ControllerExtension
      def dumbcourse_redirect_legacy
        target = DiscourseDumbcourse::LegacyRedirect.redirect_for(request, cookies)
        redirect_to(target, allow_other_host: false) if target
      end
    end
  end
end
