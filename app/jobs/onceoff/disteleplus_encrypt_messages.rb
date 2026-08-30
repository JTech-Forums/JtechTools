# frozen_string_literal: true

module Jobs
  # Encrypts message text written before at-rest encryption existed.
  class DisteleplusEncryptMessages < ::Jobs::Onceoff
    def execute_onceoff(_args)
      return unless DiscourseDisteleplus::Crypto.enabled?

      DiscourseDisteleplus::Message.find_each do |message|
        if DiscourseDisteleplus::Crypto.encrypted?(message[:raw]) &&
             DiscourseDisteleplus::Crypto.encrypted?(message[:cooked])
          next
        end
        message.update_columns(
          raw: DiscourseDisteleplus::Crypto.encrypt(message[:raw]),
          cooked: DiscourseDisteleplus::Crypto.encrypt(message[:cooked]),
        )
      end
    end
  end
end
