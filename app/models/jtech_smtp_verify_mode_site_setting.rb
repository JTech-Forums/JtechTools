# frozen_string_literal: true

require "enum_site_setting"

# Mail::SMTP#ssl_context upcases these strings into OpenSSL::SSL::VERIFY_*.
class JtechSmtpVerifyModeSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "Verify (recommended)", value: "peer" },
      { name: "Do not verify", value: "none" },
    ]
  end
end
