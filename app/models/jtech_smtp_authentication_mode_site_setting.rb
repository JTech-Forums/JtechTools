# frozen_string_literal: true

require "enum_site_setting"

# Values MUST match the auth types registered with net-smtp exactly:
# Net::SMTP::Authenticator.auth_class does `auth_classes[type.intern]` with no
# case or punctuation normalisation, so "PLAIN" or "cram-md5" would raise
# ArgumentError at delivery time — out of the Sidekiq job, killing outbound
# mail. NONE is a Jtech-only sentinel — the handler maps it to nil rather
# than passing it to Mail.
class JtechSmtpAuthenticationModeSiteSetting < EnumSiteSetting
  NONE = "none"

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "PLAIN", value: "plain" },
      { name: "LOGIN", value: "login" },
      { name: "CRAM-MD5", value: "cram_md5" },
      { name: "None (no authentication)", value: NONE },
    ]
  end
end
