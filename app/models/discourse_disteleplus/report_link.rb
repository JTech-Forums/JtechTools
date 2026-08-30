# frozen_string_literal: true

module DiscourseDisteleplus
  # One row per (Reviewable ↔ Telegram report message) pairing. Guarantees a
  # reviewable is announced at most once and remembers which Telegram message
  # to edit when the reviewable is resolved (from either side).
  class ReportLink < ActiveRecord::Base
    self.table_name = "disteleplus_report_links"

    belongs_to :reviewable, optional: true

    enum :status, { open: 0, resolved: 1 }, prefix: true

    scope :for_reviewable, ->(reviewable_id) { where(reviewable_id: reviewable_id) }
  end
end

# == Schema Information
#
# Table name: disteleplus_report_links
#
#  id                  :bigint           not null, primary key
#  reviewable_id       :bigint           not null
#  telegram_chat_id    :bigint           not null
#  telegram_message_id :bigint           not null
#  status              :integer          default("open"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_disteleplus_report_links_on_reviewable_id  (reviewable_id) UNIQUE
#  idx_disteleplus_report_links_tg                  (telegram_chat_id,telegram_message_id) UNIQUE
#
