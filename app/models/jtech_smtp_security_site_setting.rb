# frozen_string_literal: true

require "enum_site_setting"

# A single enum rather than separate TLS/STARTTLS booleans: Mail::SMTP raises
# ArgumentError when :tls and :enable_starttls* are both truthy, so the
# invalid combination must be unrepresentable.
class JtechSmtpSecuritySiteSetting < EnumSiteSetting
  STARTTLS_AUTO = "starttls_auto"
  STARTTLS_ALWAYS = "starttls_always"
  TLS = "tls"
  NONE = "none"

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "STARTTLS (opportunistic)", value: STARTTLS_AUTO },
      { name: "STARTTLS (required)", value: STARTTLS_ALWAYS },
      { name: "Implicit TLS (SMTPS)", value: TLS },
      { name: "None (plaintext)", value: NONE },
    ]
  end
end
