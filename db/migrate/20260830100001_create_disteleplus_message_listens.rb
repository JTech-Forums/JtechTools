# frozen_string_literal: true

class CreateDisteleplusMessageListens < ActiveRecord::Migration[7.2]
  def change
    create_table :disteleplus_message_listens do |t|
      t.bigint :message_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :disteleplus_message_listens, %i[message_id user_id], unique: true
    add_foreign_key :disteleplus_message_listens, :disteleplus_messages, column: :message_id
  end
end
