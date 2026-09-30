# frozen_string_literal: true
# Jtech sub-plugin body: Another SMTP. Instance_eval'd by plugin.rb in the
# Plugin::Instance context.
#
# Mechanism: not an interceptor and not a delivery_method swap. The
# :before_email_send hook fires immediately before message.deliver! and
# DiscourseAnotherSmtp::Relay rewrites that message's Mail::SMTP settings in
# place. Group inbox mail (group SMTP) is left on the group's own mailbox.

require_relative "../lib/discourse_another_smtp/relay"

after_initialize do
  if respond_to?(:register_problem_check)
    register_problem_check ::ProblemCheck::AnotherSmtpUnconfigured
  end

  on(:before_email_send) do |message, type|
    DiscourseAnotherSmtp::Relay.apply(message, type)
  end
end
