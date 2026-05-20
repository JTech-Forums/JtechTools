# frozen_string_literal: true

require "rack/mime"

module DiscourseDumbcourse
  class AppController < ::ActionController::Base
    requires_plugin DiscourseDumbcourse::PLUGIN_NAME
    include ::CurrentUser

    layout false
    skip_before_action :verify_authenticity_token
    before_action :ensure_enabled
    before_action :relax_security_headers
    before_action :redirect_anonymous_to_login

    def show
      public_root = DiscourseDumbcourse::Engine.root.join("public")
      request_path = params[:path].to_s
      request_path = request_path.split("?", 2).first.to_s

      format = params[:format].to_s
      if format != "" && request_path != "" && !request_path.end_with?(".#{format}")
        request_path = "#{request_path}.#{format}"
      end

      if request_path != ""
        safe_path = Pathname.new(request_path).cleanpath.to_s
        safe_path = safe_path.sub(%r{\A\.+/}, "")
        file_path = public_root.join(safe_path)

        if file_path.file?
          ext = file_path.extname.downcase
          mime =
            case ext
            when ".css"
              "text/css; charset=utf-8"
            when ".js"
              "text/javascript; charset=utf-8"
            when ".json"
              "application/json; charset=utf-8"
            else
              Rack::Mime.mime_type(file_path.to_s, "application/octet-stream")
            end
          response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
          return send_data(File.binread(file_path), disposition: "inline", type: mime)
        end
      end

      index_path = public_root.join("index.html")
      unless index_path.file?
        return render plain: "Dumbcourse index missing", status: :internal_server_error
      end

      response.headers["Cache-Control"] = "no-store"
      html = File.read(index_path)
      asset_version =
        (
          begin
            [
              public_root.join("dumbcourse.js").mtime.to_i,
              public_root.join("dumbcourse.css").mtime.to_i,
            ].max
          rescue StandardError
            Time.now.to_i
          end
        )
      html =
        html.gsub(/(dumbcourse\.(?:js|css)\?v=)\d+/) { Regexp.last_match(1) + asset_version.to_s }
      settings = {
        defaultTheme: SiteSetting.dumbcourse_default_theme,
        defaultView: SiteSetting.dumbcourse_default_view,
        hcaptchaEnabled: SiteSetting.discourse_hcaptcha_enabled,
        hcaptchaSiteKey: SiteSetting.hcaptcha_site_key.to_s,
        basePath: DiscourseDumbcourse.base_path_with_slash,
        paginationEnabled: SiteSetting.dumbcourse_pagination_enabled,
        topicsPerPage: SiteSetting.dumbcourse_topics_per_page,
        showCategoryNames: SiteSetting.dumbcourse_show_category_names,
        topicPostersVisibility: SiteSetting.dumbcourse_topic_posters_visibility,
        onlineGlowEnabled: SiteSetting.dumbcourse_online_glow_enabled,
        languagetoolEnabled: SiteSetting.dumbcourse_languagetool_enabled,
      }
      settings_script = "<script>window.DUMBCOURSE_SETTINGS=#{settings.to_json};</script>"
      if html.include?("</head>")
        html = html.sub("</head>", "#{settings_script}</head>")
      else
        html = settings_script + html
      end

      base_path = DiscourseDumbcourse.base_path_with_slash
      html = html.gsub(%r{"/dumb(?=/|")}, "\"#{base_path}")
      render plain: html, content_type: "text/html; charset=utf-8"
    end

    def hcaptcha
      raise Discourse::NotFound unless SiteSetting.discourse_hcaptcha_enabled
      token = params[:token].to_s
      raise Discourse::InvalidAccess.new if token.blank?

      temp_id = SecureRandom.uuid
      Discourse.redis.setex("hCaptchaToken_#{temp_id}", 2.minutes.to_i, token)
      cookies.encrypted[:h_captcha_temp_id] = {
        value: temp_id,
        httponly: true,
        secure: SiteSetting.force_https,
        expires: 2.minutes.from_now,
        same_site: :none,
      }.compact

      render json: { success: "OK" }
    end

    private

    def login_path_request?
      path = params[:path]
      path = path.to_s
      path = path.split("?", 2).first.to_s
      if path.empty?
        raw_path = request.path.to_s
        dumb_prefix = "#{Discourse.base_path}#{DiscourseDumbcourse.base_path_with_slash}"
        if raw_path == dumb_prefix
          path = ""
        elsif raw_path.start_with?("#{dumb_prefix}/")
          path = raw_path.sub("#{dumb_prefix}/", "")
        end
      end
      format = params[:format].to_s
      path = "#{path}.#{format}" if format != "" && path != "" && !path.end_with?(".#{format}")
      return true if path == "dumbcourse.css" || path == "dumbcourse.js"
      return true if path&.start_with?("dumbcourse.css") || path&.start_with?("dumbcourse.js")
      return true if path == "login" || path&.start_with?("login/")
      return true if path == "signup" || path&.start_with?("signup/")
      return true if path == "register" || path&.start_with?("register/")
      return true if path == "emoji_map.json"
      return true if path == "hcaptcha"
      false
    end

    def redirect_anonymous_to_login
      return if authenticated?
      return if login_path_request?

      redirect_to "#{Discourse.base_path}#{DiscourseDumbcourse.base_path_with_slash}/login"
    end

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.dumbcourse_enabled
    end

    def authenticated?
      current_user.present? || CurrentUser.has_auth_cookie?(request.env)
    end

    def relax_security_headers
      response.headers[
        "Content-Security-Policy"
      ] = "default-src * data: blob: 'unsafe-inline' 'unsafe-eval' http: https:;"
      response.headers["Cross-Origin-Opener-Policy"] = "unsafe-none"
      response.headers["Cross-Origin-Embedder-Policy"] = "unsafe-none"
      response.headers["Cross-Origin-Resource-Policy"] = "cross-origin"
      response.headers["X-Frame-Options"] = "ALLOWALL"
      response.headers.delete("X-Content-Type-Options")
      response.headers.delete("X-XSS-Protection")
      response.headers["Referrer-Policy"] = "unsafe-url"
      response.headers["X-Permitted-Cross-Domain-Policies"] = "all"
      response.headers.delete("Permissions-Policy")
    end
  end
end
