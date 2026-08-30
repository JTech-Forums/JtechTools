# frozen_string_literal: true

module DiscourseDisteleplus
  class Message < ActiveRecord::Base
    self.table_name = "disteleplus_messages"

    MAX_RAW_LENGTH = 20_000

    belongs_to :user, optional: true
    belongs_to :reply_to,
               class_name: "DiscourseDisteleplus::Message",
               optional: true,
               inverse_of: :replies
    has_many :replies,
             class_name: "DiscourseDisteleplus::Message",
             foreign_key: :reply_to_id,
             inverse_of: :reply_to,
             dependent: :nullify
    has_many :message_uploads,
             class_name: "DiscourseDisteleplus::MessageUpload",
             inverse_of: :message,
             dependent: :destroy
    has_many :uploads, through: :message_uploads
    has_many :reactions,
             class_name: "DiscourseDisteleplus::Reaction",
             inverse_of: :message,
             dependent: :destroy
    has_many :listens,
             class_name: "DiscourseDisteleplus::MessageListen",
             inverse_of: :message,
             dependent: :destroy
    has_many :message_links,
             class_name: "DiscourseDisteleplus::MessageLink",
             foreign_key: :disteleplus_message_id,
             inverse_of: :message,
             dependent: :destroy

    enum :source, { discourse: 0, telegram: 1 }, prefix: true

    validates :raw,
              length: {
                maximum: MAX_RAW_LENGTH,
              },
              unless: -> { Crypto.encrypted?(self[:raw]) }
    validates :source, presence: true
    validate :reply_cannot_reference_self

    scope :timeline, -> { order(id: :desc) }
    scope :not_deleted, -> { where(deleted_at: nil) }

    before_save :encrypt_content

    def deleted?
      deleted_at.present?
    end

    # Text is encrypted at rest (see Crypto); these accessors are transparent.
    def raw
      Crypto.decrypt(self[:raw])
    end

    def cooked
      Crypto.decrypt(self[:cooked])
    end

    def raw=(value)
      super(value.to_s)
    end

    def cooked=(value)
      super(value.to_s)
    end

    private

    def encrypt_content
      self[:raw] = Crypto.encrypt(self[:raw]) if will_save_change_to_raw?
      self[:cooked] = Crypto.encrypt(self[:cooked]) if will_save_change_to_cooked?
    end

    def reply_cannot_reference_self
      errors.add(:reply_to_id, "cannot reference itself") if id.present? && reply_to_id == id
    end
  end
end

# == Schema Information
#
# Table name: disteleplus_messages
#
#  id                     :bigint           not null, primary key
#  cooked                 :text             default(""), not null
#  deleted_at             :datetime
#  edited_at              :datetime
#  external_sender_name   :string
#  raw                    :text             default(""), not null
#  source                 :integer          default("discourse"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  legacy_chat_message_id :bigint
#  reply_to_id            :bigint
#  user_id                :bigint
#
# Indexes
#
#  index_disteleplus_messages_on_created_at              (created_at)
#  index_disteleplus_messages_on_legacy_chat_message_id  (legacy_chat_message_id) UNIQUE
#  index_disteleplus_messages_on_reply_to_id             (reply_to_id)
#  index_disteleplus_messages_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (reply_to_id => disteleplus_messages.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
