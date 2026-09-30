# frozen_string_literal: true

module DiscourseAnotherSmtp
  # Rewrites one outgoing message's Mail::SMTP settings to point at the
  # alternate relay. Runs from :before_email_send, immediately before
  # message.deliver!, so it only touches that message's own settings hash
  # (ActionMailer builds a fresh delivery method per message).
  #
  # It is a PARTIAL override: host, port, transport security, verification,
  # HELO domain, timeouts and credentials are replaced; everything else stays
  # at what GlobalSetting.smtp_settings produced.
  module Relay
    # Group inbox mail goes out through the group's own mailbox (Group
    # SMTP settings); rerouting it would send it from someone else's server
    # with the wrong login.
    SKIPPED_TYPES = %w[group_smtp].freeze

    def self.enabled?
      SiteSetting.jtech_enabled && SiteSetting.discourse_another_email_enabled &&
        SiteSetting.discourse_another_email_smtp_address.present?
    end

    def self.applies_to?(message, type)
      return false unless enabled?
      return false if SKIPPED_TYPES.include?(type.to_s)
      !group_mailbox?(Array(message.from).first)
    end

    # Same test Email::Sender uses to tag a message as group SMTP mail.
    def self.group_mailbox?(from)
      from.present? && Group.where(email_username: from, smtp_enabled: true).exists?
    end

    def self.apply(message, type)
      return unless applies_to?(message, type)

      settings = message.delivery_method.settings
      apply_endpoint(settings)
      apply_security(settings)
      apply_authentication(settings)
      rewrite_from(message)
      force_username_to_sender(message, settings)
    rescue StandardError => e
      # Email::Sender only rescues SMTP errors — anything raised here would
      # escape into the Sidekiq job and take down all outbound mail with no
      # admin-visible signal. Log and let the message go out on whatever
      # settings were applied so far.
      Rails.logger.error(
        "[jtech-tools another_smtp] before_email_send failed: #{e.class}: #{e.message}",
      )
    end

    def self.apply_endpoint(settings)
      settings[:address] = SiteSetting.discourse_another_email_smtp_address.strip
      settings[:port] = SiteSetting.discourse_another_email_smtp_port
      settings[:openssl_verify_mode] = SiteSetting.discourse_another_email_smtp_openssl_verify_mode
      settings[:open_timeout] = SiteSetting.discourse_another_email_smtp_open_timeout_seconds
      settings[:read_timeout] = SiteSetting.discourse_another_email_smtp_read_timeout_seconds

      helo = SiteSetting.discourse_another_email_smtp_domain.strip.presence
      settings[:domain] = helo if helo
    end

    # Every nil below is load-bearing: mail's setting_provided? is
    # `!settings[k].nil?`, so false and nil mean different things, and
    # Mail::SMTP raises if :tls and :enable_starttls* are both truthy.
    def self.apply_security(settings)
      case SiteSetting.discourse_another_email_smtp_security
      when JtechSmtpSecuritySiteSetting::TLS
        settings[:tls] = settings[:ssl] = true
        settings[:enable_starttls] = settings[:enable_starttls_auto] = false
      when JtechSmtpSecuritySiteSetting::STARTTLS_ALWAYS
        settings[:tls] = settings[:ssl] = nil
        settings[:enable_starttls] = :always
        settings[:enable_starttls_auto] = nil
      when JtechSmtpSecuritySiteSetting::STARTTLS_AUTO
        settings[:tls] = settings[:ssl] = settings[:enable_starttls] = nil
        settings[:enable_starttls_auto] = true
      when JtechSmtpSecuritySiteSetting::NONE
        settings[:tls] = settings[:ssl] = nil
        settings[:enable_starttls] = settings[:enable_starttls_auto] = false
      end
    end

    # Credentials must become nil, not "" — net-smtp still issues AUTH for an
    # empty string, which fails at the relay instead of skipping AUTH.
    def self.apply_authentication(settings)
      mode = SiteSetting.discourse_another_email_smtp_authentication_mode
      username = SiteSetting.discourse_another_email_smtp_username.strip.presence
      password = SiteSetting.discourse_another_email_smtp_password.presence

      if mode == JtechSmtpAuthenticationModeSiteSetting::NONE || (username.nil? && password.nil?)
        settings[:authentication] = settings[:user_name] = settings[:password] = nil
      else
        settings[:authentication] = mode
        settings[:user_name] = username
        settings[:password] = password
      end
    end

    # Reads the address OBJECTS, not the flattened strings — message.from
    # returns bare addresses with display names already stripped;
    # Mail::Address#display_name is the only way to keep the name.
    def self.rewrite_from(message)
      domain = SiteSetting.discourse_another_email_force_from_domain.strip.presence
      return if domain.nil? || message[:from].nil?

      message.from =
        message[:from].addrs.map do |a|
          addr = a.address.to_s
          next a.to_s if addr.exclude?("@")
          rewritten = "#{addr.split("@").first}@#{domain}"
          a.display_name.present? ? "#{a.display_name} <#{rewritten}>" : rewritten
        end
    end

    # Runs after the domain rewrite, so the AUTH user carries the rewritten
    # domain. Never turns AUTH back on when authentication resolved to none.
    def self.force_username_to_sender(message, settings)
      return if settings[:user_name].nil?
      return unless SiteSetting.discourse_another_email_force_smtp_username_to_sender

      sender = Array(message.from).first.to_s
      return if sender.exclude?("@")

      local_part, domain = sender.split("@", 2)
      settings[:user_name] = "#{local_part.split("+").first}@#{domain}"
    end
  end
end
