# frozen_string_literal: true

module DiscourseDumbcourse
  # "Sign in with another device": a phone that can't comfortably type a
  # password shows a short code; the owner, signed in elsewhere, enters it
  # and approves; the phone is signed in. Like a TV's device login.
  #
  # State lives in Redis for ten minutes. The code alone is not enough to
  # receive the session: the requesting browser also holds a random secret
  # in an encrypted, HttpOnly cookie, and only that browser can collect the
  # approval. Codes are 8 characters from a 31-letter alphabet (~40 bits),
  # and looking codes up is rate limited per person and per IP address.
  module Pairing
    ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze
    CODE_LENGTH = 8
    TTL = 10.minutes
    POLL_INTERVAL = 3

    class Error < StandardError
      attr_reader :reason

      def initialize(reason)
        @reason = reason
        super(reason.to_s)
      end
    end

    def self.enabled?
      DiscourseDumbcourse.enabled? && SiteSetting.dumbcourse_device_pairing_enabled
    end

    def self.normalize(code)
      code.to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, CODE_LENGTH]
    end

    def self.digest(secret)
      Digest::SHA256.hexdigest("dumbcourse-pair:#{secret}")
    end

    def self.code_key(code)
      "dumbcourse:pair:code:#{code}"
    end

    def self.secret_key(digest)
      "dumbcourse:pair:secret:#{digest}"
    end

    def self.redis
      Discourse.redis
    end

    # Starts a pairing. Returns [code, secret]; the secret goes to the
    # requesting browser only, in a cookie.
    def self.start!(user_agent:, ip:)
      secret = SecureRandom.hex(32)
      code = nil
      5.times do
        candidate =
          Array.new(CODE_LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join
        entry = {
          secret_digest: digest(secret),
          user_agent: user_agent.to_s[0, 300],
          ip: ip.to_s,
          created_at: Time.zone.now.to_i,
          status: "pending",
          user_id: nil,
        }
        if redis.set(code_key(candidate), entry.to_json, ex: TTL.to_i, nx: true)
          code = candidate
          break
        end
      end
      raise Error.new(:busy) if code.nil?
      redis.setex(secret_key(digest(secret)), TTL.to_i, code)
      [code, secret]
    end

    def self.find(code)
      raw = redis.get(code_key(normalize(code)))
      raw && JSON.parse(raw).with_indifferent_access
    rescue JSON::ParserError
      nil
    end

    def self.save(code, entry)
      ttl = redis.ttl(code_key(code))
      return if ttl.to_i <= 0
      redis.setex(code_key(code), ttl, entry.to_json)
    end

    # What the approving person sees before saying yes.
    def self.describe(entry, viewer_ip:)
      {
        device: describe_agent(entry[:user_agent]),
        approximate_location: describe_ip(entry[:ip], viewer_ip),
        requested_at: Time.zone.at(entry[:created_at].to_i).iso8601,
      }
    end

    def self.describe_agent(ua)
      ua = ua.to_s
      device =
        case ua
        when /KAIOS/i
          "KaiOS phone"
        when /Android/i
          "Android device"
        when /iPhone|iPad|iPod/i
          "iPhone or iPad"
        when /Windows/i
          "Windows computer"
        when /Macintosh|Mac OS X/i
          "Mac"
        when /Linux/i
          "Linux computer"
        else
          "Unknown device"
        end
      browser =
        case ua
        when %r{Firefox/(\d+)}
          "Firefox #{$1}"
        when %r{Edg/(\d+)}
          "Edge #{$1}"
        when %r{OPR/(\d+)|Opera}
          "Opera"
        when %r{Chrome/(\d+)}
          "Chrome #{$1}"
        when %r{Version/(\d+).*Safari}
          "Safari #{$1}"
        else
          "a browser"
        end
      "#{device}, #{browser}"
    end

    # Enough to tell "that's me, here" from "that's someone else": the
    # network the request came from, partly masked, and whether it matches
    # the approver's.
    def self.describe_ip(ip, viewer_ip)
      return nil if ip.blank?
      same = ip == viewer_ip.to_s
      masked =
        if ip.include?(":")
          ip.split(":").first(3).join(":") + ":…"
        else
          ip.split(".").first(3).join(".") + ".x"
        end
      if same
        "Same network as you (#{masked})"
      else
        "From network #{masked} — not the one you're on now"
      end
    end

    def self.approve!(code, user)
      code = normalize(code)
      entry = find(code)
      raise Error.new(:not_found) if entry.nil? || entry[:status] != "pending"
      entry[:status] = "approved"
      entry[:user_id] = user.id
      save(code, entry)
    end

    def self.deny!(code)
      code = normalize(code)
      entry = find(code)
      raise Error.new(:not_found) if entry.nil? || entry[:status] != "pending"
      entry[:status] = "denied"
      save(code, entry)
    end

    # For the requesting browser: its pairing's status, by its secret.
    # Returns [status, user] and forgets the pairing once it's settled.
    def self.collect(secret)
      return "expired", nil if secret.blank?
      d = digest(secret)
      code = redis.get(secret_key(d))
      entry = code && find(code)
      return "expired", nil if entry.nil?
      # The secret must match the one this code was created with.
      unless ActiveSupport::SecurityUtils.secure_compare(entry[:secret_digest].to_s, d)
        return "expired", nil
      end

      case entry[:status]
      when "approved"
        forget(code, d)
        user = User.find_by(id: entry[:user_id])
        user && can_sign_in?(user) ? ["approved", user] : ["denied", nil]
      when "denied"
        forget(code, d)
        ["denied", nil]
      else
        ["pending", nil]
      end
    end

    def self.forget(code, digest)
      redis.del(code_key(code))
      redis.del(secret_key(digest))
    end

    def self.can_sign_in?(user)
      return false if user.staged? || user.suspended? || !user.active?
      return false if SiteSetting.must_approve_users? && !user.approved? && !user.staff?
      true
    end
  end
end
