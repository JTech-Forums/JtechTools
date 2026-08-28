# frozen_string_literal: true

class CreateDisteleplusForumUploadLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :disteleplus_forum_upload_links do |t|
      t.bigint :post_id, null: false
      t.bigint :upload_id, null: false
      t.bigint :telegram_chat_id, null: false
      t.bigint :telegram_message_id, null: false
      t.bigint :telegram_topic_id, null: false
      # Snapshot the content identity so lookup survives a later detached or
      # deleted Upload row. Very old/imported uploads may not have a SHA-1.
      t.string :upload_sha1, limit: 40
      t.boolean :file_copied, null: false, default: true
      t.timestamps
    end

    add_index :disteleplus_forum_upload_links,
              %i[post_id upload_id],
              unique: true,
              name: "idx_disteleplus_forum_upload_post_upload"
    add_index :disteleplus_forum_upload_links,
              %i[telegram_chat_id telegram_message_id],
              unique: true,
              name: "idx_disteleplus_forum_upload_telegram"
    add_index :disteleplus_forum_upload_links, :upload_id
    add_index :disteleplus_forum_upload_links, :upload_sha1
  end
end
