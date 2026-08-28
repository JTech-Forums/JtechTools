# frozen_string_literal: true

require "rails_helper"

# Inbound pipeline behavior with the two external seams stubbed: ChatAdapter
# (so the chat plugin is not required) and TelegramApi (no network). What's
# real here: gating, echo suppression, user matching, formatting, and the
# link rows.
RSpec.describe Jobs::DisteleplusProcessTelegramUpdate do
  fab!(:user) { Fabricate(:user, username: "tgmatch") }

  let(:adapter) { DiscourseDisteleplus::ChatAdapter }
  let(:chat_id) { -100_555 }
  let(:channel_id) { 42 }
  let(:fake_message) { Struct.new(:id).new(9001) }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_telegram_chat_id = chat_id.to_s
    SiteSetting.disteleplus_chat_channel_id = channel_id
    SiteSetting.disteleplus_bridge_bot_username = "telegram_bridge"

    allow(DiscourseDisteleplus).to receive(:chat_available?).and_return(true)
    allow(adapter).to receive(:ensure_membership)
    allow(adapter).to receive(:create_message).and_return(fake_message)
    allow(adapter).to receive(:update_message)
    allow(adapter).to receive(:react)
    allow(adapter).to receive(:find_message) { Struct.new(:user).new(bot) }
  end

  let(:bot) { DiscourseDisteleplus.bot_user }

  def message_update(overrides = {})
    {
      "update_id" => 1,
      "message" => {
        "message_id" => 77,
        "chat" => {
          "id" => chat_id,
        },
        "from" => {
          "id" => 1,
          "is_bot" => false,
          "first_name" => "Zev",
          "username" => "someone",
        },
        "text" => "hello from telegram",
      }.merge(overrides),
    }
  end

  def run(update)
    described_class.new.execute(update: update)
  end

  it "creates the bot user lazily at TL4" do
    expect(bot).to be_present
    expect(bot.trust_level).to eq(TrustLevel[4])
  end

  it "names an inbound Telegram voice message as a voice note with its duration" do
    tempfile = Tempfile.new(%w[voice .oga], binmode: true)
    tempfile.write("OggS")
    tempfile.rewind
    allow_any_instance_of(DiscourseDisteleplus::TelegramApi).to receive(:download_file).and_return(
      tempfile,
    )
    upload = Struct.new(:id, :persisted?).new(501, true)
    creator = instance_double(UploadCreator, create_for: upload)
    allow(UploadCreator).to receive(:new).and_return(creator)

    run(
      message_update(
        "text" => nil,
        "voice" => {
          "file_id" => "AwAC",
          "duration" => 25,
          "mime_type" => "audio/ogg",
          "file_size" => 4000,
        },
      ),
    )

    expect(UploadCreator).to have_received(:new).with(
      tempfile,
      "voice-note-25s.ogg",
      type: "composer",
    )
    expect(adapter).to have_received(:create_message).with(a_hash_including(upload_ids: [501]))
  end

  it "ignores messages from other Telegram chats" do
    run(message_update("chat" => { "id" => -1 }))
    expect(adapter).not_to have_received(:create_message)
  end

  it "keeps human replies in the forum-upload topic out of Discourse Chat" do
    SiteSetting.disteleplus_forum_uploads_enabled = true
    SiteSetting.disteleplus_forum_upload_topic_id = 99
    run(message_update("message_thread_id" => 99))
    expect(adapter).not_to have_received(:create_message)
  end

  it "accepts only the configured Telegram chat topic when one is set" do
    SiteSetting.disteleplus_chat_topic_id = 42
    run(message_update("message_thread_id" => 41))
    expect(adapter).not_to have_received(:create_message)

    run(message_update("message_thread_id" => 42))
    expect(adapter).to have_received(:create_message).once
  end

  it "skips messages already linked (echo layer 2)" do
    DiscourseDisteleplus::MessageLink.create!(
      telegram_chat_id: chat_id,
      telegram_message_id: 77,
      chat_message_id: 1,
      direction: :tg_to_discourse,
    )
    run(message_update)
    expect(adapter).not_to have_received(:create_message)
  end

  it "posts as the matched Discourse user without a prefix" do
    run(message_update("from" => { "id" => 1, "username" => "tgmatch", "first_name" => "Zev" }))
    expect(adapter).to have_received(:create_message).with(
      a_hash_including(user: user, text: "hello from telegram"),
    )
  end

  it "prefers the manual mapping over the automatic match" do
    other = Fabricate(:user, username: "mapped_target")
    SiteSetting.disteleplus_user_map = [
      { "telegram_username" => "tgmatch", "discourse_username" => "mapped_target" },
    ].to_json
    run(message_update("from" => { "id" => 1, "username" => "tgmatch" }))
    expect(adapter).to have_received(:create_message).with(a_hash_including(user: other))
  end

  it "posts unmatched senders as the bot with a name prefix" do
    run(message_update)
    expect(adapter).to have_received(:create_message).with(
      a_hash_including(user: bot, text: "**Zev (TG):** hello from telegram"),
    )
  end

  it "records a tg_to_discourse link row" do
    expect { run(message_update) }.to change { DiscourseDisteleplus::MessageLink.count }.by(1)
    link = DiscourseDisteleplus::MessageLink.last
    expect(link.telegram_message_id).to eq(77)
    expect(link.chat_message_id).to eq(fake_message.id)
    expect(link).to be_tg_to_discourse
  end

  it "threads replies through the link table" do
    DiscourseDisteleplus::MessageLink.create!(
      telegram_chat_id: chat_id,
      telegram_message_id: 50,
      chat_message_id: 500,
      direction: :tg_to_discourse,
    )
    run(message_update("reply_to_message" => { "message_id" => 50 }))
    expect(adapter).to have_received(:create_message).with(a_hash_including(in_reply_to_id: 500))
  end

  it "renders polls as markdown and links the poll id" do
    poll = {
      "id" => "987",
      "question" => "Lunch?",
      "total_voter_count" => 1,
      "is_anonymous" => true,
      "options" => [{ "text" => "Pizza", "voter_count" => 1 }],
    }
    run(message_update("text" => nil, "poll" => poll))
    expect(adapter).to have_received(:create_message).with(
      a_hash_including(text: a_string_including("📊 **Poll:** Lunch?", "Pizza — 1 (100%)")),
    )
    expect(DiscourseDisteleplus::MessageLink.last.telegram_poll_id).to eq("987")
  end

  describe "edited_message" do
    let!(:link) do
      DiscourseDisteleplus::MessageLink.create!(
        telegram_chat_id: chat_id,
        telegram_message_id: 77,
        chat_message_id: 9001,
        direction: :tg_to_discourse,
      )
    end

    def edit_update(text: "edited!")
      update = message_update("text" => text)
      { "update_id" => 2, "edited_message" => update["message"] }
    end

    it "revises the linked chat message" do
      run(edit_update)
      expect(adapter).to have_received(:update_message).with(
        a_hash_including(message_id: 9001, text: a_string_including("edited!")),
      )
    end

    it "does nothing when edit bridging is off" do
      SiteSetting.disteleplus_bridge_edits = false
      run(edit_update)
      expect(adapter).not_to have_received(:update_message)
    end

    it "ignores edits of unlinked (pre-bridge) messages" do
      link.destroy!
      run(edit_update)
      expect(adapter).not_to have_received(:update_message)
    end
  end

  describe "message_reaction" do
    let!(:link) do
      DiscourseDisteleplus::MessageLink.create!(
        telegram_chat_id: chat_id,
        telegram_message_id: 77,
        chat_message_id: 9001,
        direction: :tg_to_discourse,
      )
    end

    def reaction_update(old: [], new: [{ "type" => "emoji", "emoji" => "🔥" }], user_name: "tgmatch")
      {
        "update_id" => 3,
        "message_reaction" => {
          "chat" => {
            "id" => chat_id,
          },
          "message_id" => 77,
          "user" => {
            "id" => 1,
            "username" => user_name,
          },
          "old_reaction" => old,
          "new_reaction" => new,
        },
      }
    end

    it "adds a mapped reaction as the matched user" do
      run(reaction_update)
      expect(adapter).to have_received(:react).with(
        a_hash_including(message_id: 9001, user: user, emoji: "fire", action: :add),
      )
    end

    it "removes reactions dropped from the new list" do
      run(reaction_update(old: [{ "type" => "emoji", "emoji" => "🔥" }], new: []))
      expect(adapter).to have_received(:react).with(
        a_hash_including(emoji: "fire", action: :remove),
      )
    end

    it "reacts as the bot for unmatched users" do
      run(reaction_update(user_name: "stranger"))
      expect(adapter).to have_received(:react).with(a_hash_including(user: bot))
    end

    it "drops custom-emoji reactions" do
      run(reaction_update(new: [{ "type" => "custom_emoji", "custom_emoji_id" => "5" }]))
      expect(adapter).not_to have_received(:react)
    end

    it "skips unlinked messages" do
      link.destroy!
      run(reaction_update)
      expect(adapter).not_to have_received(:react)
    end

    it "does nothing when reaction bridging is off" do
      SiteSetting.disteleplus_bridge_reactions = false
      run(reaction_update)
      expect(adapter).not_to have_received(:react)
    end
  end

  it "does nothing at all when the module is disabled" do
    SiteSetting.disteleplus_enabled = false
    run(message_update)
    expect(adapter).not_to have_received(:create_message)
  end
end
