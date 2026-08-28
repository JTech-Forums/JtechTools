# frozen_string_literal: true

# The alternate-SMTP settings used to ship placeholder junk as defaults
# (address 172.17.0.1, username username@example.com, password "password").
# Those defaults are now blank, and a blank address makes the handler no-op.
# A site that had the module ENABLED and was relying on any of the old
# defaults (never overridden ⇒ no site_settings row) would silently fall
# back to the global relay on upgrade — so materialize the old defaults as
# explicit overrides for such sites. Sites with the module off get the new
# clean defaults.
class MaterializeAnotherSmtpDefaults < ActiveRecord::Migration[7.2]
  # data_type 1 = string, 3 = integer (SiteSettings::TypeSupervisor.types)
  OLD_DEFAULTS = [
    ["discourse_another_email_smtp_address", 1, "172.17.0.1"],
    ["discourse_another_email_smtp_port", 3, "587"],
    ["discourse_another_email_smtp_authentication_mode", 7, "plain"],
    ["discourse_another_email_smtp_username", 1, "username@example.com"],
    ["discourse_another_email_smtp_password", 1, "password"],
  ].freeze

  def up
    enabled =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'discourse_another_email_enabled'",
      ).first
    return unless enabled == "t"

    OLD_DEFAULTS.each do |name, data_type, value|
      DB.exec(<<~SQL, name: name, data_type: data_type, value: value)
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES (:name, :data_type, :value, NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    # Overrides are indistinguishable from admin-set values; leave them.
  end
end
