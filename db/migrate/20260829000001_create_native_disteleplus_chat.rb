# frozen_string_literal: true

class CreateNativeDisteleplusChat < ActiveRecord::Migration[7.2]
  def change
    create_table :disteleplus_messages do |t|
      t.bigint :user_id
      t.bigint :reply_to_id
      t.text :raw, null: false, default: ""
      t.text :cooked, null: false, default: ""
      t.integer :source, null: false, default: 0
      t.string :external_sender_name
      t.datetime :edited_at
      t.datetime :deleted_at
      t.bigint :legacy_chat_message_id
      t.timestamps
    end

    add_index :disteleplus_messages, :user_id
    add_index :disteleplus_messages, :reply_to_id
    add_index :disteleplus_messages, :created_at
    add_index :disteleplus_messages, :legacy_chat_message_id, unique: true
    add_foreign_key :disteleplus_messages, :users, column: :user_id, on_delete: :nullify
    add_foreign_key :disteleplus_messages,
                    :disteleplus_messages,
                    column: :reply_to_id,
                    on_delete: :nullify

    create_table :disteleplus_message_uploads do |t|
      t.bigint :message_id, null: false
      t.bigint :upload_id, null: false
      t.timestamps
    end

    add_index :disteleplus_message_uploads,
              %i[message_id upload_id],
              unique: true,
              name: "idx_disteleplus_message_uploads_unique"
    add_index :disteleplus_message_uploads, :upload_id
    add_foreign_key :disteleplus_message_uploads,
                    :disteleplus_messages,
                    column: :message_id,
                    on_delete: :cascade
    add_foreign_key :disteleplus_message_uploads, :uploads, on_delete: :cascade

    create_table :disteleplus_reactions do |t|
      t.bigint :message_id, null: false
      t.bigint :user_id, null: false
      t.string :emoji, null: false, limit: 100
      t.timestamps
    end

    add_index :disteleplus_reactions,
              %i[message_id user_id emoji],
              unique: true,
              name: "idx_disteleplus_reactions_unique"
    add_index :disteleplus_reactions, :user_id
    add_foreign_key :disteleplus_reactions,
                    :disteleplus_messages,
                    column: :message_id,
                    on_delete: :cascade
    add_foreign_key :disteleplus_reactions, :users, on_delete: :cascade

    create_table :disteleplus_user_states do |t|
      t.bigint :user_id, null: false
      t.bigint :last_read_message_id
      t.integer :notification_level, null: false, default: 1
      t.timestamps
    end

    add_index :disteleplus_user_states, :user_id, unique: true
    add_index :disteleplus_user_states, :last_read_message_id
    add_foreign_key :disteleplus_user_states, :users, on_delete: :cascade
    add_foreign_key :disteleplus_user_states,
                    :disteleplus_messages,
                    column: :last_read_message_id,
                    on_delete: :nullify

    add_column :disteleplus_message_links, :disteleplus_message_id, :bigint
    add_index :disteleplus_message_links, :disteleplus_message_id
    add_foreign_key :disteleplus_message_links,
                    :disteleplus_messages,
                    column: :disteleplus_message_id,
                    on_delete: :cascade
    change_column_null :disteleplus_message_links, :chat_message_id, true
  end
end
