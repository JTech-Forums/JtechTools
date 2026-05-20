# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `discourse-another-smtp/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.

# [Jtech] removed top-level: enabled_site_setting :discourse_another_email_enabled

after_initialize do
  
  DiscourseEvent.on(:before_email_send) do |*params|

    if SiteSetting.discourse_another_email_enabled
  
      message, type = *params

      message.delivery_method.settings[:authentication] = SiteSetting.discourse_another_email_smtp_authentication_mode
      message.delivery_method.settings[:address] = SiteSetting.discourse_another_email_smtp_address
      message.delivery_method.settings[:port] = SiteSetting.discourse_another_email_smtp_port
      message.delivery_method.settings[:password] = SiteSetting.discourse_another_email_smtp_password
      message.delivery_method.settings[:user_name] = SiteSetting.discourse_another_email_smtp_username
      
      # Force from domain if configured
      force_domain = SiteSetting.discourse_another_email_force_from_domain
      if force_domain.present?
        # Get the current from address
        from_addresses = message.from
        if from_addresses && from_addresses.any?
          # Replace domain for each from address
          new_from_addresses = from_addresses.map do |addr|
            if addr.include?('@')
              local_part = addr.split('@').first
              # Preserve display name if present
              if addr.include?('<') && addr.include?('>')
                # Format: "Display Name <email@domain.com>"
                display_name = addr.split('<').first.strip
                if display_name.present?
                  "#{display_name} <#{local_part}@#{force_domain}>"
                else
                  "#{local_part}@#{force_domain}"
                end
              else
                # Simple email format
                "#{local_part}@#{force_domain}"
              end
            else
              addr
            end
          end
          message.from = new_from_addresses
        end
      end
      
      # Force SMTP username to match sender address if configured
      if SiteSetting.discourse_another_email_force_smtp_username_to_sender
        from_addresses = message.from
        if from_addresses && from_addresses.any?
          # Get the first from address and extract just the email part
          first_from = from_addresses.first
          email_address = if first_from.include?('<') && first_from.include?('>')
            # Extract email from "Display Name <email@domain.com>" format
            first_from.match(/<(.+)>/)[1]
          else
            # Already in simple email format
            first_from
          end
          
          # Strip plus addressing from the email
          if email_address.include?('@')
            local_part, domain = email_address.split('@')
            # Remove plus addressing (e.g., user+tag@domain.com becomes user@domain.com)
            local_part = local_part.split('+').first
            smtp_username = "#{local_part}@#{domain}"
          else
            smtp_username = email_address
          end
          
          # Update the SMTP username to match the sender (without plus addressing)
          message.delivery_method.settings[:user_name] = smtp_username
        end
      end
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
