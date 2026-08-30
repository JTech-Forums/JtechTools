# frozen_string_literal: true

require "rails_helper"

# Reports pipeline with TelegramApi stubbed: reviewable announcements,
# resolution edits, and — most importantly — the callback authorization
# rules (reports chat + explicit telegram_id staff mapping, nothing less).
RSpec.describe DiscourseDisteleplus::Reports do
  fab!(:admin) { Fabricate(:admin, username: "bigboss") }
  fab!(:flagger) { Fabricate(:user, username: "snitch") }
  fab!(:post)

  let(:api) { instance_double(DiscourseDisteleplus::TelegramApi) }
  let(:chat_id) { "-100777" }
  let(:ok_result) do
    DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "message_id" => 555 })
  end

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_bot_token = "token"
    SiteSetting.disteleplus_telegram_chat_id = chat_id
    SiteSetting.disteleplus_reports_enabled = true
    SiteSetting.disteleplus_reports_topic_id = 9

    allow(DiscourseDisteleplus::TelegramApi).to receive(:new).and_return(api)
    allow(api).to receive(:call).and_return(ok_result)
  end

  def flag!
    result = PostActionCreator.spam(flagger, post)
    result.reviewable ||
      Fabricate(:reviewable_flagged_post, target: post, topic: post.topic, created_by: flagger)
  end

  def map_admin!(tg_id: "42")
    SiteSetting.disteleplus_user_map = [
      {
        "telegram_username" => "boss_tg",
        "discourse_username" => admin.username,
        "telegram_id" => tg_id,
      },
    ].to_json
  end

  def callback(intent:, reviewable:, from_id: 42, from_username: "boss_tg", chat: chat_id)
    {
      "id" => "cbq1",
      "from" => {
        "id" => from_id,
        "username" => from_username,
      },
      "message" => {
        "message_id" => 555,
        "chat" => {
          "id" => chat.to_i,
        },
      },
      "data" => "dtp:#{intent}:#{reviewable.id}",
    }
  end

  describe ".notify_reviewable" do
    it "announces a pending reviewable with the action keyboard and links it" do
      reviewable = flag!
      expect { described_class.notify_reviewable(reviewable) }.to change {
        DiscourseDisteleplus::ReportLink.count
      }.by(1)
      expect(api).to have_received(:call).with(
        "sendMessage",
        a_hash_including(
          chat_id: chat_id,
          parse_mode: "HTML",
          message_thread_id: 9,
          reply_markup:
            a_hash_including(
              inline_keyboard: [
                [
                  a_hash_including(callback_data: "dtp:approve:#{reviewable.id}"),
                  a_hash_including(callback_data: "dtp:deny:#{reviewable.id}"),
                  a_hash_including(callback_data: "dtp:more:#{reviewable.id}"),
                ],
              ],
            ),
        ),
      )
    end

    it "is idempotent per reviewable" do
      reviewable = flag!
      described_class.notify_reviewable(reviewable)
      expect { described_class.notify_reviewable(reviewable) }.not_to change {
        DiscourseDisteleplus::ReportLink.count
      }
    end
  end

  describe ".handle_callback" do
    it "rejects pressers without an explicit telegram_id staff mapping" do
      reviewable = flag!
      described_class.notify_reviewable(reviewable)

      # Same @username as the mapped admin but a different numeric id — the
      # classic re-claimed-username spoof.
      map_admin!(tg_id: "42")
      described_class.handle_callback(
        callback(intent: "approve", reviewable: reviewable, from_id: 666),
      )

      expect(reviewable.reload).to be_pending
      expect(api).to have_received(:call).with(
        "answerCallbackQuery",
        a_hash_including(text: I18n.t("disteleplus.reports.not_authorized"), show_alert: true),
      )
    end

    it "rejects callbacks from a foreign chat" do
      reviewable = flag!
      map_admin!
      described_class.handle_callback(
        callback(intent: "approve", reviewable: reviewable, chat: "-100123"),
      )
      expect(reviewable.reload).to be_pending
    end

    it "performs the approve action for a mapped staff presser" do
      reviewable = flag!
      described_class.notify_reviewable(reviewable)
      map_admin!

      described_class.handle_callback(callback(intent: "approve", reviewable: reviewable))

      expect(reviewable.reload).to be_approved
    end

    it "edits the report message with the resolver once resolved" do
      reviewable = flag!
      described_class.notify_reviewable(reviewable)
      reviewable.perform(admin, :agree_and_keep)

      described_class.mark_resolved(reviewable.reload, status: "approved")

      expect(api).to have_received(:call).with(
        "editMessageText",
        a_hash_including(message_id: 555, text: include("bigboss")),
      )
      expect(DiscourseDisteleplus::ReportLink.last).to be_status_resolved
    end
  end

  describe ".reports_thread_in_bridge_chat?" do
    it "flags the reports topic only when it shares the bridged group" do
      expect(described_class.reports_thread_in_bridge_chat?(9)).to eq(true)
      expect(described_class.reports_thread_in_bridge_chat?(8)).to eq(false)
      SiteSetting.disteleplus_reports_chat_id = "-100999"
      expect(described_class.reports_thread_in_bridge_chat?(9)).to eq(false)
    end
  end
end
