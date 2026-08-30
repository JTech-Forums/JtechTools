# frozen_string_literal: true

class CreateDisteleplusReportLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :disteleplus_report_links do |t|
      t.bigint :reviewable_id, null: false
      t.bigint :telegram_chat_id, null: false
      t.bigint :telegram_message_id, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :disteleplus_report_links, :reviewable_id, unique: true
    add_index :disteleplus_report_links,
              %i[telegram_chat_id telegram_message_id],
              unique: true,
              name: "idx_disteleplus_report_links_tg"
  end
end
