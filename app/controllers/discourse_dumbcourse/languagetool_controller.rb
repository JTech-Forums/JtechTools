# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module DiscourseDumbcourse
  class LanguagetoolController < ::ApplicationController
    requires_plugin DiscourseDumbcourse::PLUGIN_NAME
    requires_login
    skip_before_action :verify_authenticity_token

    def check
      raise Discourse::NotFound unless SiteSetting.dumbcourse_languagetool_enabled

      text = params[:text].to_s
      return render json: { error: "text required" }, status: :bad_request if text.blank?

      language = params[:language].to_s.strip
      language = "auto" if language.blank?

      mode = SiteSetting.dumbcourse_languagetool_mode.to_s
      if mode == "official_api"
        url = SiteSetting.dumbcourse_languagetool_api_url.to_s.strip
        if url.blank?
          return(
            render(
              json: {
                error: "LanguageTool API URL not configured",
              },
              status: :unprocessable_entity,
            )
          )
        end
      else
        url = SiteSetting.dumbcourse_languagetool_url.to_s.strip
        if url.blank?
          return(
            render(
              json: {
                error: "LanguageTool URL not configured",
              },
              status: :unprocessable_entity,
            )
          )
        end
      end

      uri = build_languagetool_uri(url)
      req = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"] = "application/x-www-form-urlencoded"
      params_body = { language: language, text: text }
      if mode == "official_api"
        username = SiteSetting.dumbcourse_languagetool_api_username.to_s.strip
        api_key = SiteSetting.dumbcourse_languagetool_api_key.to_s.strip
        if username.present? && api_key.blank?
          return(
            render(
              json: {
                error: "LanguageTool API key required for username",
              },
              status: :unprocessable_entity,
            )
          )
        end
        params_body[:username] = username if username.present?
        params_body[:apiKey] = api_key if api_key.present?
      else
        apply_secret_header(req)
      end
      req.body = URI.encode_www_form(params_body)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 3
      http.read_timeout = 10

      resp = http.request(req)
      unless resp.is_a?(Net::HTTPSuccess)
        return(
          render(
            json: {
              error: "LanguageTool error",
              status: resp.code.to_i,
            },
            status: :bad_gateway,
          )
        )
      end

      data =
        begin
          JSON.parse(resp.body)
        rescue JSON::ParserError
          nil
        end
      matches = data && data["matches"].is_a?(Array) ? data["matches"] : nil
      unless matches
        return render json: { error: "Invalid LanguageTool response" }, status: :bad_gateway
      end

      render json: { matches: matches }
    rescue StandardError => e
      Rails.logger.warn("[Dumbcourse LT] Error: #{e.class}: #{e.message}")
      render json: { error: "LanguageTool request failed" }, status: :bad_gateway
    end

    private

    def build_languagetool_uri(raw)
      url = raw.to_s.strip
      url = "http://#{url}" unless url.start_with?("http://", "https://")
      uri = URI.parse(url)

      path = uri.path.to_s
      if path.empty? || path == "/"
        uri.path = "/v2/check"
      elsif path.end_with?("/v2")
        uri.path = path + "/check"
      elsif path.end_with?("/v2/")
        uri.path = path + "check"
      elsif !path.end_with?("/v2/check")
        uri.path = path.sub(%r{/+\z}, "") + "/v2/check"
      end

      uri
    end

    def apply_secret_header(req)
      secret = SiteSetting.dumbcourse_languagetool_secret.to_s.strip
      return if secret.blank?

      if secret.include?(":")
        name, value = secret.split(":", 2)
        return if name.to_s.strip.empty?

        req[name.to_s.strip] = value.to_s.strip
      else
        req["Authorization"] = "Bearer #{secret}"
      end
    end
  end
end
