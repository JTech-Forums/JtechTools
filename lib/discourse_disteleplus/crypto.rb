# frozen_string_literal: true

module DiscourseDisteleplus
  # At-rest encryption for message text. AES-256-GCM via Rails'
  # MessageEncryptor with a key derived from the app secret, so a database
  # dump alone does not expose the conversation. Values are prefixed so
  # plaintext rows written before this existed still read back correctly.
  module Crypto
    PREFIX = "enc:v1:"
    SALT = "disteleplus-message-at-rest"

    def self.enabled?
      SiteSetting.respond_to?(:disteleplus_encrypt_at_rest) &&
        SiteSetting.disteleplus_encrypt_at_rest
    end

    def self.encryptor
      @encryptor ||=
        begin
          key =
            ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
              SALT,
              32,
            )
          ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
        end
    end

    def self.encrypted?(value)
      value.is_a?(String) && value.start_with?(PREFIX)
    end

    def self.encrypt(value)
      return value if value.blank? || encrypted?(value) || !enabled?
      PREFIX + encryptor.encrypt_and_sign(value)
    end

    def self.decrypt(value)
      return value unless encrypted?(value)
      encryptor.decrypt_and_verify(value.delete_prefix(PREFIX))
    rescue ActiveSupport::MessageEncryptor::InvalidMessage,
           ActiveSupport::MessageVerifier::InvalidSignature
      ""
    end
  end
end
