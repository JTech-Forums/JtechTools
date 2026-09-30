# frozen_string_literal: true

# REQ-PM: users exchange contact details (phone, WhatsApp, email, …) with
# each other instead of messaging on the forum. Every user-typed value is
# stored encrypted (see DiscourseReqpm::Crypto); these tables only ever hold
# ciphertext for them.
class CreateReqpmTables < ActiveRecord::Migration[7.2]
  def change
    # One row per way to reach a user.
    create_table :reqpm_contact_methods do |t|
      t.bigint :user_id, null: false
      t.string :kind, null: false, limit: 20
      # Custom methods only: the user's own name for it and a Discourse
      # emoji name. The label is user text, so it is encrypted too.
      t.text :label_ciphertext
      t.string :emoji, limit: 100
      t.text :value_ciphertext, null: false
      t.text :note_ciphertext
      # Pre-ticked in the "send my info" picker.
      t.boolean :share_by_default, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :reqpm_contact_methods, %i[user_id position]
    add_foreign_key :reqpm_contact_methods, :users, on_delete: :cascade

    # "owner let recipient see this one method". Deleting the method, or
    # either user, takes the grant with it.
    create_table :reqpm_shares do |t|
      t.bigint :owner_id, null: false
      t.bigint :recipient_id, null: false
      t.bigint :contact_method_id, null: false
      t.timestamps
    end
    add_index :reqpm_shares, %i[contact_method_id recipient_id], unique: true
    add_index :reqpm_shares, %i[recipient_id owner_id]
    add_index :reqpm_shares, %i[owner_id recipient_id]
    add_foreign_key :reqpm_shares, :users, column: :owner_id, on_delete: :cascade
    add_foreign_key :reqpm_shares, :users, column: :recipient_id, on_delete: :cascade
    add_foreign_key :reqpm_shares,
                    :reqpm_contact_methods,
                    column: :contact_method_id,
                    on_delete: :cascade

    # "requester asked target for their details". No free text on purpose —
    # only which kinds of contact they would like.
    create_table :reqpm_requests do |t|
      t.bigint :requester_id, null: false
      t.bigint :target_id, null: false
      t.integer :status, null: false, default: 0
      t.string :wanted_kinds, array: true, null: false, default: []
      t.datetime :responded_at
      t.timestamps
    end
    add_index :reqpm_requests, %i[target_id status]
    add_index :reqpm_requests,
              %i[requester_id target_id created_at],
              name: "index_reqpm_requests_on_pair_and_created_at"
    # At most one open request per direction.
    add_index :reqpm_requests,
              %i[requester_id target_id],
              unique: true,
              where: "status = 0",
              name: "index_reqpm_requests_one_pending_per_pair"
    add_foreign_key :reqpm_requests, :users, column: :requester_id, on_delete: :cascade
    add_foreign_key :reqpm_requests, :users, column: :target_id, on_delete: :cascade
  end
end
