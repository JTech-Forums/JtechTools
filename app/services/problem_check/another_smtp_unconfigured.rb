# frozen_string_literal: true

# Admin dashboard problem check: the alternate relay is switched on but has
# no address, so every email is still going out through the server's own
# SMTP host.
class ProblemCheck::AnotherSmtpUnconfigured < ProblemCheck
  self.priority = "high"

  def call
    return no_problem unless SiteSetting.jtech_enabled
    return no_problem unless SiteSetting.discourse_another_email_enabled
    return no_problem if SiteSetting.discourse_another_email_smtp_address.present?

    problem
  end
end
