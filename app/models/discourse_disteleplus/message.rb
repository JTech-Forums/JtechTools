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
    has_many :message_links,
             class_name: "DiscourseDisteleplus::MessageLink",
             foreign_key: :disteleplus_message_id,
             inverse_of: :message,
             dependent: :destroy

    enum :source, { discourse: 0, telegram: 1 }, prefix: true

    validates :raw, length: { maximum: MAX_RAW_LENGTH }
    validates :source, presence: true
    validate :reply_cannot_reference_self

    scope :timeline, -> { order(id: :desc) }
    scope :not_deleted, -> { where(deleted_at: nil) }

    def deleted?
      deleted_at.present?
    end

    private

    def reply_cannot_reference_self
      errors.add(:reply_to_id, "cannot reference itself") if id.present? && reply_to_id == id
    end
  end
end
