# frozen_string_literal: true

module DiscourseDisteleplus
  # One row per (Telegram message ↔ Discourse chat message) pairing. Serves
  # both directions: echo suppression (a linked message is never re-bridged)
  # and edit/delete/reply/poll/reaction target lookup.
  #
  # A Discourse message with N uploads fans out to N Telegram messages, so
  # chat_message_id is deliberately NOT unique; `.first` on the
  # telegram_message_id-ordered scope is the primary (caption-carrying) edit
  # target.
  class MessageLink < ActiveRecord::Base
    self.table_name = "disteleplus_message_links"

    belongs_to :message,
               class_name: "DiscourseDisteleplus::Message",
               foreign_key: :disteleplus_message_id,
               inverse_of: :message_links,
               optional: true

    enum :direction, { tg_to_discourse: 0, discourse_to_tg: 1 }, scopes: true
    enum :kind, { text: 0, media: 1, poll: 2 }, prefix: true

    scope :for_telegram,
          ->(chat_id, message_id) do
            where(telegram_chat_id: chat_id, telegram_message_id: message_id)
          end
    scope :for_chat_message,
          ->(chat_message_id) do
            where(chat_message_id: chat_message_id).order(:telegram_message_id)
          end
    scope :for_message,
          ->(message_id) do
            where(disteleplus_message_id: message_id).order(:telegram_message_id)
          end
  end
end

# == Schema Information
#
# Table name: disteleplus_message_links
#
#  id                  :bigint           not null, primary key
#  direction           :integer          not null
#  kind                :integer          default("text"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chat_message_id     :bigint           not null
#  telegram_chat_id    :bigint           not null
#  telegram_message_id :bigint           not null
#  telegram_poll_id    :string
#
# Indexes
#
#  idx_disteleplus_links_tg                             (telegram_chat_id,telegram_message_id) UNIQUE
#  index_disteleplus_message_links_on_chat_message_id   (chat_message_id)
#  index_disteleplus_message_links_on_telegram_poll_id  (telegram_poll_id)
#
