# frozen_string_literal: true

class CreateDisteleplusMessageLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :disteleplus_message_links do |t|
      t.bigint :telegram_chat_id, null: false
      t.bigint :telegram_message_id, null: false
      t.bigint :chat_message_id, null: false
      t.integer :direction, null: false
      t.string :telegram_poll_id
      t.integer :kind, null: false, default: 0
      t.timestamps
    end

    add_index :disteleplus_message_links,
              %i[telegram_chat_id telegram_message_id],
              unique: true,
              name: "idx_disteleplus_links_tg"
    add_index :disteleplus_message_links, :chat_message_id
    add_index :disteleplus_message_links, :telegram_poll_id
  end
end
