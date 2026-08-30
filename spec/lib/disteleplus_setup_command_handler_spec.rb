# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::SetupCommandHandler do
  let(:api) { instance_double(DiscourseDisteleplus::TelegramApi) }
  let(:admin_result) do
    DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "status" => "administrator" })
  end
  let(:sent_result) do
    DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "message_id" => 500 })
  end
  let(:message) do
    {
      "message_id" => 20,
      "chat" => {
        "id" => -100_555,
        "type" => "supergroup",
        "title" => "JTech",
      },
      "from" => {
        "id" => 42,
      },
      "text" => "/disteleplus_help",
    }
  end

  before do
    SiteSetting.disteleplus_setup_commands_enabled = true
    SiteSetting.disteleplus_telegram_chat_id = ""
    SiteSetting.disteleplus_chat_topic_id = 0
    SiteSetting.disteleplus_forum_upload_topic_id = 0
    SiteSetting.disteleplus_forum_upload_topic_name = "Uploads"

    # `anything` resolves to Mocha's matcher here, which an rspec-mocks
    # verifying double cannot match against. Use RSpec's own matchers.
    allow(api).to receive(:call).with(
      "getChatMember",
      a_hash_including(chat_id: -100_555, user_id: 42),
    ).and_return(admin_result)
    allow(api).to receive(:call).with(
      "sendMessage",
      a_hash_including(chat_id: -100_555),
    ).and_return(sent_result)
    # /disteleplus_status now checks whether Telegram delivers button presses
    # (callback_delivery_state); an empty allowed_updates means "everything".
    allow(api).to receive(:call).with("getWebhookInfo").and_return(
      DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "allowed_updates" => [] }),
    )
  end

  def process(payload = message)
    described_class.new(payload, api: api).process?
  end

  it "does not consume ordinary Telegram messages" do
    message["text"] = "hello"
    expect(process).to eq(false)
    expect(api).not_to have_received(:call)
  end

  it "binds General without requiring an ID from the administrator" do
    message["text"] = "/disteleplus_bind_general"
    expect(process).to eq(true)

    expect(SiteSetting.disteleplus_telegram_chat_id).to eq("-100555")
    expect(SiteSetting.disteleplus_chat_topic_id).to eq(0)
    expect(api).to have_received(:call).with(
      "sendMessage",
      a_hash_including(text: a_string_including("General bound")),
    )
  end

  it "binds the current topic and remembers its human name" do
    message["text"] = "/disteleplus_bind_uploads App Uploads"
    message["message_thread_id"] = 77
    process

    expect(SiteSetting.disteleplus_telegram_chat_id).to eq("-100555")
    expect(SiteSetting.disteleplus_forum_upload_topic_id).to eq(77)
    expect(SiteSetting.disteleplus_forum_upload_topic_name).to eq("App Uploads")
    expect(api).to have_received(:call).with(
      "sendMessage",
      a_hash_including(message_thread_id: 77, text: a_string_including("Upload topic bound")),
    )
  end

  it "can create and bind a named topic" do
    message["text"] = "/disteleplus_create_uploads App Uploads"
    created =
      DiscourseDisteleplus::TelegramApi::Result.new(
        ok: true,
        result: {
          "message_thread_id" => 88,
          "name" => "App Uploads",
        },
      )
    allow(api).to receive(:call).with(
      "createForumTopic",
      chat_id: -100_555,
      name: "App Uploads",
    ).and_return(created)

    process

    expect(SiteSetting.disteleplus_forum_upload_topic_id).to eq(88)
    expect(SiteSetting.disteleplus_forum_upload_topic_name).to eq("App Uploads")
  end

  it "rejects non-admin setup without changing destinations" do
    non_admin =
      DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "status" => "member" })
    allow(api).to receive(:call).with(
      "getChatMember",
      a_hash_including(chat_id: -100_555, user_id: 42),
    ).and_return(non_admin)
    message["text"] = "/disteleplus_bind_uploads"
    message["message_thread_id"] = 77

    process

    expect(SiteSetting.disteleplus_forum_upload_topic_id).to eq(0)
    expect(api).to have_received(:call).with(
      "sendMessage",
      a_hash_including(text: a_string_including("Only a Telegram group administrator")),
    )
  end

  it "reports the native conversation, notification and voice-note state in /disteleplus_status" do
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_telegram_chat_id = "-100555"
    allow(DiscourseDisteleplus::ChannelNotifications).to receive(:status_summary).and_return(
      "on — 3/3 native members at always, push on",
    )
    allow(DiscourseDisteleplus::VoiceNotes).to receive(:ffmpeg_available?).and_return(true)
    message["text"] = "/disteleplus_status"

    process

    expect(api).to have_received(:call).with(
      "sendMessage",
      a_hash_including(
        text:
          a_string_including(
            "Native conversation: /disteleplus",
            "Telegram conversation: General",
            "Notifications: on — 3/3 native members at always, push on",
            "Voice notes: on — native conversation",
          ),
      ),
    )
  end

  it "queues a notification sync from /disteleplus_sync_notifications" do
    SiteSetting.disteleplus_force_channel_notifications = true
    message["text"] = "/disteleplus_sync_notifications"

    expect_enqueued_with(job: :disteleplus_sync_channel_notifications) { process }
    expect(api).to have_received(:call).with(
      "sendMessage",
      a_hash_including(text: a_string_including("Notification sync queued")),
    )
  end

  it "explains when the sync command is run with forced notifications off" do
    SiteSetting.disteleplus_force_channel_notifications = false
    message["text"] = "/disteleplus_sync_notifications"

    process

    expect(api).to have_received(:call).with(
      "sendMessage",
      a_hash_including(text: a_string_including("Forced notifications are off")),
    )
  end

  it "does not let an administrator in another group hijack an existing binding" do
    SiteSetting.disteleplus_telegram_chat_id = "-100999"
    message["text"] = "/disteleplus_bind_uploads"
    message["message_thread_id"] = 77

    process

    expect(SiteSetting.disteleplus_telegram_chat_id).to eq("-100999")
    expect(SiteSetting.disteleplus_forum_upload_topic_id).to eq(0)
    expect(api).to have_received(:call).with(
      "sendMessage",
      a_hash_including(text: a_string_including("already bound to another group")),
    )
  end
end
