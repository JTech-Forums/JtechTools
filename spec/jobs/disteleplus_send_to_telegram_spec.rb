# frozen_string_literal: true

require "rails_helper"

# Outbound behavior with TelegramApi and ChatAdapter stubbed: link rows drive
# create/edit/delete/react routing, and every Telegram payload is asserted.
RSpec.describe Jobs::DisteleplusSendToTelegram do
  fab!(:author) { Fabricate(:user, username: "chatter") }

  let(:adapter) { DiscourseDisteleplus::ChatAdapter }
  let(:api) { instance_double(DiscourseDisteleplus::TelegramApi) }
  let(:chat_id) { "-100555" }
  let(:ok_result) do
    DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "message_id" => 321 })
  end
  let(:chat_message_struct) { Struct.new(:id, :message, :user, :in_reply_to_id) }
  let(:chat_message) { chat_message_struct.new(9001, "hi there", author, nil) }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_telegram_chat_id = chat_id

    allow(DiscourseDisteleplus::TelegramApi).to receive(:new).and_return(api)
    allow(api).to receive(:call).and_return(ok_result)
    allow(adapter).to receive(:find_message).and_return(chat_message)
    allow(adapter).to receive(:message_uploads).and_return([])
    allow(adapter).to receive(:current_reaction_emojis).and_return([])
  end

  def link!(direction: :discourse_to_tg, kind: :text, tg_id: 321, chat_message_id: 9001)
    DiscourseDisteleplus::MessageLink.create!(
      telegram_chat_id: chat_id.to_i,
      telegram_message_id: tg_id,
      chat_message_id: chat_message_id,
      direction: direction,
      kind: kind,
    )
  end

  def run(action)
    described_class.new.execute(action: action, chat_message_id: 9001)
  end

  describe "create" do
    it "sends HTML text with the author prefix and records the link" do
      expect { run("create") }.to change { DiscourseDisteleplus::MessageLink.count }.by(1)
      expect(api).to have_received(:call).with(
        "sendMessage",
        hash_including(chat_id: chat_id, parse_mode: "HTML", text: "<b>chatter:</b> hi there"),
      )
      link = DiscourseDisteleplus::MessageLink.last
      expect(link.telegram_message_id).to eq(321)
      expect(link).to be_discourse_to_tg
    end

    it "escapes HTML in the message body" do
      allow(chat_message).to receive(:message).and_return("<script>x & y</script>")
      run("create")
      expect(api).to have_received(:call).with(
        "sendMessage",
        hash_including(text: "<b>chatter:</b> &lt;script&gt;x &amp; y&lt;/script&gt;"),
      )
    end

    it "skips messages that are already linked (echo guard)" do
      link!
      run("create")
      expect(api).not_to have_received(:call)
    end

    it "threads Telegram replies via the link table" do
      link!(tg_id: 42, chat_message_id: 8000)
      allow(chat_message).to receive(:in_reply_to_id).and_return(8000)
      run("create")
      expect(api).to have_received(:call).with(
        "sendMessage",
        hash_including(reply_to_message_id: 42),
      )
    end
  end

  describe "edit" do
    it "uses editMessageText for text links" do
      link!(kind: :text)
      run("edit")
      expect(api).to have_received(:call).with(
        "editMessageText",
        hash_including(message_id: 321, text: "<b>chatter:</b> hi there"),
      )
    end

    it "uses editMessageCaption for media links" do
      link!(kind: :media)
      run("edit")
      expect(api).to have_received(:call).with(
        "editMessageCaption",
        hash_including(message_id: 321, caption: "<b>chatter:</b> hi there"),
      )
    end

    it "ignores edits of unlinked messages" do
      run("edit")
      expect(api).not_to have_received(:call)
    end
  end

  describe "delete" do
    it "deletes every linked Telegram message and removes the links" do
      link!(tg_id: 321)
      link!(tg_id: 322, kind: :media)
      expect { run("delete") }.to change { DiscourseDisteleplus::MessageLink.count }.by(-2)
      expect(api).to have_received(:call).with("deleteMessage", hash_including(message_id: 321))
      expect(api).to have_received(:call).with("deleteMessage", hash_including(message_id: 322))
    end

    it "never touches tg_to_discourse links (the humans' own messages)" do
      link!(direction: :tg_to_discourse)
      run("delete")
      expect(api).not_to have_received(:call)
    end
  end

  describe "react" do
    before { link! }

    it "mirrors the most recent Discourse reaction" do
      allow(adapter).to receive(:current_reaction_emojis).and_return(%w[+1 fire])
      run("react")
      expect(api).to have_received(:call).with(
        "setMessageReaction",
        hash_including(message_id: 321, reaction: [{ type: "emoji", emoji: "🔥" }]),
      )
    end

    it "falls back to 👍 for unmapped emoji" do
      allow(adapter).to receive(:current_reaction_emojis).and_return(%w[some_exotic_emoji])
      run("react")
      expect(api).to have_received(:call).with(
        "setMessageReaction",
        hash_including(reaction: [{ type: "emoji", emoji: "👍" }]),
      )
    end

    it "clears the bot reaction when no reactions remain" do
      run("react")
      expect(api).to have_received(:call).with("setMessageReaction", hash_including(reaction: []))
    end
  end

  it "does nothing when the module is disabled" do
    SiteSetting.disteleplus_enabled = false
    run("create")
    expect(api).not_to have_received(:call)
  end
end
