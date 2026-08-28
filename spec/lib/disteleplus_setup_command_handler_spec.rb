# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::SetupCommandHandler do
  let(:api) { instance_double(DiscourseDisteleplus::TelegramApi) }
  let(:admin_result) do
    DiscourseDisteleplus::TelegramApi::Result.new(
      ok: true,
      result: { "status" => "administrator" },
    )
  end
  let(:sent_result) do
    DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "message_id" => 500 })
  end
  let(:message) do
    {
      "message_id" => 20,
      "chat" => { "id" => -100_555, "type" => "supergroup", "title" => "JTech" },
      "from" => { "id" => 42 },
      "text" => "/disteleplus_help",
    }
  end

  before do
    SiteSetting.disteleplus_setup_commands_enabled = true
    SiteSetting.disteleplus_telegram_chat_id = ""
    SiteSetting.disteleplus_chat_topic_id = 0
    SiteSetting.disteleplus_forum_upload_topic_id = 0
    SiteSetting.disteleplus_forum_upload_topic_name = "Uploads"

    allow(api).to receive(:call).with("getChatMember", anything).and_return(admin_result)
    allow(api).to receive(:call).with("sendMessage", anything).and_return(sent_result)
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
        result: { "message_thread_id" => 88, "name" => "App Uploads" },
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
    allow(api).to receive(:call).with("getChatMember", anything).and_return(non_admin)
    message["text"] = "/disteleplus_bind_uploads"
    message["message_thread_id"] = 77

    process

    expect(SiteSetting.disteleplus_forum_upload_topic_id).to eq(0)
    expect(api).to have_received(:call).with(
      "sendMessage",
      a_hash_including(text: a_string_including("Only a Telegram group administrator")),
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
