# frozen_string_literal: true

module DiscourseDumbcourse
  # Endpoints for "Sign in with another device" (see Pairing).
  #
  #   POST /<base>/auth/pair           the phone asks for a code (signed out)
  #   GET  /<base>/auth/pair/poll      the phone waits for approval
  #   GET  /<base>/auth/pair/lookup    the owner checks a code's device
  #   POST /<base>/auth/pair/approve   …and approves it
  #   POST /<base>/auth/pair/deny      …or turns it down
  class PairController < ::ApplicationController
    requires_plugin "jtech-tools"

    COOKIE = :dumbcourse_pair

    skip_before_action :redirect_to_login_if_required, only: %i[create poll]
    skip_before_action :check_xhr, raise: false
    before_action :ensure_pairing_enabled
    before_action :ensure_logged_in, only: %i[lookup approve deny]
    before_action :ensure_real_session, only: %i[lookup approve deny]

    rescue_from Pairing::Error do |e|
      status = e.reason == :not_found ? 404 : 422
      render json:
               failed_json.merge(
                 error: I18n.t("dumbcourse.pairing.#{e.reason}", default: e.reason.to_s),
               ),
             status: status
    end

    def create
      raise Discourse::InvalidAccess.new if current_user
      RateLimiter.new(nil, "dumbcourse-pair-start-#{request.remote_ip}", 10, 1.hour).performed!
      code, secret = Pairing.start!(user_agent: request.user_agent, ip: request.remote_ip)
      cookies.encrypted[COOKIE] = {
        value: secret,
        httponly: true,
        secure: SiteSetting.force_https || request.ssl?,
        same_site: :lax,
        expires: Pairing::TTL.from_now,
      }
      response.headers["Cache-Control"] = "no-store"
      render json: {
               code: code,
               expires_in: Pairing::TTL.to_i,
               poll_interval: Pairing::POLL_INTERVAL,
               approve_url:
                 "#{Discourse.base_path}#{DiscourseDumbcourse.base_path_with_slash}/link",
             }
    end

    def poll
      RateLimiter.new(nil, "dumbcourse-pair-poll-#{request.remote_ip}", 400, 10.minutes).performed!
      response.headers["Cache-Control"] = "no-store"
      status, user = Pairing.collect(cookies.encrypted[COOKIE])
      if status == "approved" && user
        cookies.delete(COOKIE)
        log_on_user(user)
        Rails.logger.info(
          "[Dumbcourse] device paired for user #{user.id} from #{request.remote_ip}",
        )
      elsif status != "pending"
        cookies.delete(COOKIE)
      end
      render json: { status: status }
    end

    def lookup
      limit_lookups!
      entry = Pairing.find(params.require(:code))
      raise Pairing::Error.new(:not_found) if entry.nil? || entry[:status] != "pending"
      render json: Pairing.describe(entry, viewer_ip: request.remote_ip)
    end

    def approve
      limit_lookups!
      Pairing.approve!(params.require(:code), current_user)
      render json: success_json
    end

    def deny
      limit_lookups!
      Pairing.deny!(params.require(:code))
      render json: success_json
    end

    private

    def ensure_pairing_enabled
      raise Discourse::NotFound unless Pairing.enabled?
    end

    # Only a person signed in the ordinary way can hand out a session: not
    # an API key, and not an admin impersonating someone.
    def ensure_real_session
      raise Discourse::InvalidAccess.new if is_api? || is_user_api?
      raise Discourse::InvalidAccess.new if current_user.is_impersonating
      raise Discourse::InvalidAccess.new unless Pairing.can_sign_in?(current_user)
    end

    # Codes are guessable only by brute force; keep that out of reach.
    def limit_lookups!
      RateLimiter.new(current_user, "dumbcourse-pair-lookup", 10, 10.minutes).performed!
      RateLimiter.new(nil, "dumbcourse-pair-lookup-#{request.remote_ip}", 20, 10.minutes).performed!
    end
  end
end
