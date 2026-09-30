# frozen_string_literal: true

module DiscourseReqpm
  # One way to reach a user. The value, label and note are only ever stored
  # as ciphertext bound to the owner (see Crypto); the plain attributes
  # below read and write through it.
  class ContactMethod < ActiveRecord::Base
    self.table_name = "reqpm_contact_methods"

    ENCRYPTED = %i[value label note].freeze

    belongs_to :user
    has_many :shares,
             class_name: "DiscourseReqpm::Share",
             foreign_key: :contact_method_id,
             dependent: :delete_all

    validates :kind, inclusion: { in: Kinds::ALL }
    validates :value_ciphertext, presence: true

    scope :ordered, -> { order(:position, :id) }

    ENCRYPTED.each do |field|
      define_method(field) do
        Crypto.decrypt(public_send(:"#{field}_ciphertext"), user_id: user_id, field: field)
      end

      define_method(:"#{field}=") do |plain|
        public_send(
          :"#{field}_ciphertext=",
          plain.nil? ? nil : Crypto.encrypt(plain, user_id: user_id, field: field),
        )
      end
    end

    # Encrypted under a key this server no longer has (e.g. restored from a
    # backup onto another install). Shown to the owner as "please re-enter",
    # never to anyone else.
    def unreadable?
      value.nil?
    end

    def custom?
      kind == Kinds::CUSTOM
    end
  end
end

# == Schema Information
#
# Table name: reqpm_contact_methods
#
#  id               :bigint           not null, primary key
#  emoji            :string(100)
#  kind             :string(20)       not null
#  label_ciphertext :text
#  note_ciphertext  :text
#  position         :integer          default(0), not null
#  share_by_default :boolean          default(TRUE), not null
#  value_ciphertext :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_reqpm_contact_methods_on_user_id_and_position  (user_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
