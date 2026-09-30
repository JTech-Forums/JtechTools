# frozen_string_literal: true

module DiscourseReqpm
  # At-rest encryption for everything a user types into their contact card.
  # AES-256-GCM (authenticated) via Rails' MessageEncryptor, keyed off the
  # app secret with a REQ-PM-only salt, so a database dump or a backup file
  # on its own reveals nothing.
  #
  # Every ciphertext is bound to its owner and field through the
  # MessageEncryptor `purpose`: a value copied onto another user's row, or
  # from the note column into the value column, fails to decrypt instead of
  # being shown to the wrong person.
  #
  # The key is derived from secret_key_base, which is not part of a
  # Discourse backup. A restore onto a server with a different secret leaves
  # the rows unreadable (decrypt returns nil) and users are asked to re-enter
  # them — it never exposes or mixes up data.
  module Crypto
    PREFIX = "rqpm:v1:"
    SALT = "jtech-reqpm-contact-card-v1"

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

    def self.purpose(user_id, field)
      raise ArgumentError, "user_id required" if user_id.blank?
      "reqpm:#{user_id}:#{field}"
    end

    def self.encrypt(value, user_id:, field:)
      return nil if value.nil?
      PREFIX + encryptor.encrypt_and_sign(value.to_s, purpose: purpose(user_id, field))
    end

    # nil when the value is missing, was written under another key, or was
    # tampered with / moved to another row.
    def self.decrypt(value, user_id:, field:)
      return nil if value.blank? || !value.start_with?(PREFIX)
      encryptor.decrypt_and_verify(value.delete_prefix(PREFIX), purpose: purpose(user_id, field))
    rescue ActiveSupport::MessageEncryptor::InvalidMessage,
           ActiveSupport::MessageVerifier::InvalidSignature,
           ArgumentError
      nil
    end
  end
end
