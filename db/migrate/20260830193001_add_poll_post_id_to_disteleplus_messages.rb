# frozen_string_literal: true

# Conversation polls are powered by core's poll plugin via a backing post in
# a hidden holder topic; the message keeps a pointer to that post.
class AddPollPostIdToDisteleplusMessages < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:disteleplus_messages, :poll_post_id)
      add_column :disteleplus_messages, :poll_post_id, :bigint
    end
    unless index_exists?(:disteleplus_messages, :poll_post_id)
      add_index :disteleplus_messages, :poll_post_id
    end
  end
end
