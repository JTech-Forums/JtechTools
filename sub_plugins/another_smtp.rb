# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `discourse-another-smtp/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.
#
# Mechanism: not an interceptor and not a delivery_method swap. The
# :before_email_send hook fires immediately before message.deliver! and this
# handler mutates the per-message Mail::SMTP settings hash in place. It is a
# PARTIAL override — host, port, transport security, verification, HELO
# domain, timeouts and credentials are replaced; everything else stays at
# what GlobalSetting.smtp_settings produced. It applies to EVERY outgoing
# message, including group SMTP mail.

# [Jtech] removed top-level: enabled_site_setting :discourse_another_email_enabled
# — the handler gates on jtech_enabled + the module master at call time.

after_initialize do
  DiscourseEvent.on(:before_email_send) do |*params|
    next unless SiteSetting.jtech_enabled
    next unless SiteSetting.discourse_another_email_enabled

    begin
      message, _type = *params
      settings = message.delivery_method.settings

      # Blank address = unconfigured: leave the global relay alone entirely.
      address = SiteSetting.discourse_another_email_smtp_address.presence
      next if address.nil?

      settings[:address] = address
      settings[:port] = SiteSetting.discourse_another_email_smtp_port

      # Transport security. Every nil below is load-bearing: mail's
      # setting_provided? is `!settings[k].nil?`, so false and nil mean
      # different things, and Mail::SMTP raises if :tls and :enable_starttls*
      # are both truthy.
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

      settings[:openssl_verify_mode] = SiteSetting.discourse_another_email_smtp_openssl_verify_mode
      settings[:open_timeout] = SiteSetting.discourse_another_email_smtp_open_timeout_seconds
      settings[:read_timeout] = SiteSetting.discourse_another_email_smtp_read_timeout_seconds

      helo = SiteSetting.discourse_another_email_smtp_domain.presence
      settings[:domain] = helo if helo

      # Authentication. Credentials must become nil, not "" — net-smtp still
      # issues AUTH for an empty string (`"" ` is truthy), which fails at the
      # relay instead of skipping AUTH.
      mode = SiteSetting.discourse_another_email_smtp_authentication_mode
      username = SiteSetting.discourse_another_email_smtp_username.presence
      password = SiteSetting.discourse_another_email_smtp_password.presence

      if mode == JtechSmtpAuthenticationModeSiteSetting::NONE || (username.nil? && password.nil?)
        settings[:authentication] = nil
        settings[:user_name] = nil
        settings[:password] = nil
      else
        settings[:authentication] = mode
        settings[:user_name] = username
        settings[:password] = password
      end

      # Force From domain if configured. Read the address OBJECTS, not the
      # flattened strings — message.from returns bare addresses with display
      # names already stripped, so string parsing for "Name <addr>" never
      # matches; Mail::Address#display_name is the only way to keep the name.
      force_domain = SiteSetting.discourse_another_email_force_from_domain.presence
      if force_domain && message[:from]
        message.from =
          message[:from].addrs.map do |a|
            addr = a.address.to_s
            next a.to_s if addr.exclude?("@")
            rewritten = "#{addr.split("@").first}@#{force_domain}"
            a.display_name.present? ? "#{a.display_name} <#{rewritten}>" : rewritten
          end
      end

      # Force SMTP username to match the sender if configured. Runs after the
      # domain rewrite, so the AUTH user carries the rewritten domain. Never
      # resurrects AUTH when the mode above resolved to no authentication.
      if settings[:user_name] && SiteSetting.discourse_another_email_force_smtp_username_to_sender
        first_from = Array(message.from).first.to_s
        if first_from.include?("@")
          local_part, domain = first_from.split("@", 2)
          # Strip plus addressing (user+tag@domain → user@domain).
          settings[:user_name] = "#{local_part.split("+").first}@#{domain}"
        end
      end
    rescue StandardError => e
      # Email::Sender only rescues SMTP errors — anything raised here would
      # escape into the Sidekiq job and take down all outbound mail with no
      # admin-visible signal. Log and let the message go out on whatever
      # settings were applied so far.
      Rails.logger.error(
        "[jtech-tools another_smtp] before_email_send failed: #{e.class}: #{e.message}",
      )
    end
  end
end

# message.delivery_method.settings is like:
# {:address=>"localhost",
#  :port=>1025,
#  :domain=>"localhost.localdomain",
#  :user_name=>nil,
#  :password=>nil,
#  :authentication=>nil,
#  :enable_starttls=>nil,
#  :enable_starttls_auto=>true,
#  :openssl_verify_mode=>nil,
#  :ssl=>nil,
#  :tls=>nil,
#  :open_timeout=>5,
#  :read_timeout=>5,
#  :return_response=>true}
