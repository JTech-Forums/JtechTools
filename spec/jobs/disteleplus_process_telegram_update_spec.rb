# frozen_string_literal: true

require "rails_helper"

# Inbound pipeline behavior with TelegramApi stubbed (no network). Everything
# else is real: gating, echo suppression, user matching, formatting, native
# message/reaction rows, and the link rows that tie them to Telegram.
RSpec.describe Jobs::DisteleplusProcessTelegramUpdate do
  fab!(:user) { Fabricate(:user, username: "tgmatch") }

  let(:chat_id) { -100_555 }
  let(:messages) { DiscourseDisteleplus::Message }
  let(:links) { DiscourseDisteleplus::MessageLink }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_telegram_chat_id = chat_id.to_s
    SiteSetting.disteleplus_bridge_bot_username = "telegram_bridge"
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

  def native!(user: bot, raw: "earlier", tg_id: 77, poll_id: nil)
    message = messages.create!(user: user, raw: raw, cooked: "<p>#{raw}</p>", source: :telegram)
    links.create!(
      telegram_chat_id: chat_id,
      telegram_message_id: tg_id,
      disteleplus_message_id: message.id,
      direction: :tg_to_discourse,
      telegram_poll_id: poll_id,
    )
    message
  end

  it "creates the bot user lazily at TL4" do
    expect(bot).to be_present
    expect(bot.trust_level).to eq(TrustLevel[4])
  end

  it "creates a native Telegram-sourced message and never enqueues an outbound echo" do
    expect { run(message_update) }.to change { messages.count }.by(1)
    message = messages.last
    expect(message).to be_source_telegram
    expect(message.cooked).to include("hello from telegram")
    expect(Jobs::DisteleplusSendToTelegram.jobs).to be_empty
  end

  it "names an inbound Telegram voice message as a voice note with its duration" do
    tempfile = Tempfile.new(%w[voice .oga], binmode: true)
    tempfile.write("OggS")
    tempfile.rewind
    allow_any_instance_of(DiscourseDisteleplus::TelegramApi).to receive(:download_file).and_return(
      tempfile,
    )
    upload = Fabricate(:upload, user: bot, original_filename: "voice-note-25s.ogg", extension: "ogg")
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

    expect(UploadCreator).to have_received(:new).with(tempfile, "voice-note-25s.ogg", type: "composer")
    expect(messages.last.uploads).to eq([upload])
    expect(links.last).to be_kind_media
  end

  it "ignores messages from other Telegram chats" do
    run(message_update("chat" => { "id" => -1 }))
    expect(messages.count).to eq(0)
  end

  it "keeps human replies in the forum-upload topic out of the conversation" do
    SiteSetting.disteleplus_forum_uploads_enabled = true
    SiteSetting.disteleplus_forum_upload_topic_id = 99
    run(message_update("message_thread_id" => 99))
    expect(messages.count).to eq(0)
  end

  it "accepts only the configured Telegram chat topic when one is set" do
    SiteSetting.disteleplus_chat_topic_id = 42
    run(message_update("message_thread_id" => 41))
    expect(messages.count).to eq(0)

    run(message_update("message_thread_id" => 42))
    expect(messages.count).to eq(1)
  end

  it "skips messages already linked (echo layer 2 / webhook retry)" do
    native!
    expect { run(message_update) }.not_to change { messages.count }
  end

  it "posts as the matched Discourse user with no external sender name" do
    run(message_update("from" => { "id" => 1, "username" => "tgmatch", "first_name" => "Zev" }))
    message = messages.last
    expect(message.user).to eq(user)
    expect(message.raw).to eq("hello from telegram")
    expect(message.external_sender_name).to be_nil
  end

  it "prefers the manual mapping over the automatic match" do
    other = Fabricate(:user, username: "mapped_target")
    SiteSetting.disteleplus_user_map = [
      { "telegram_username" => "tgmatch", "discourse_username" => "mapped_target" },
    ].to_json
    run(message_update("from" => { "id" => 1, "username" => "tgmatch" }))
    expect(messages.last.user).to eq(other)
  end

  it "posts unmatched senders as the bot and stores the Telegram name structurally" do
    run(message_update)
    message = messages.last
    expect(message.user).to eq(bot)
    expect(message.external_sender_name).to eq("Zev")
    expect(message.raw).to eq("hello from telegram")
  end

  it "records a tg_to_discourse link row pointing at the native message" do
    expect { run(message_update) }.to change { links.count }.by(1)
    link = links.last
    expect(link.telegram_message_id).to eq(77)
    expect(link.disteleplus_message_id).to eq(messages.last.id)
    expect(link.chat_message_id).to be_nil
    expect(link).to be_tg_to_discourse
  end

  it "threads replies through the link table" do
    parent = native!(tg_id: 50)
    run(message_update("reply_to_message" => { "message_id" => 50 }))
    expect(messages.last.reply_to).to eq(parent)
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
    expect(messages.last.raw).to include("📊 **Poll:** Lunch?", "Pizza — 1 (100%)")
    expect(links.last.telegram_poll_id).to eq("987")
    expect(links.last).to be_kind_poll
  end

  it "drops polls when poll bridging is off" do
    SiteSetting.disteleplus_bridge_polls = false
    run(message_update("text" => nil, "poll" => { "id" => "1", "question" => "?", "options" => [] }))
    expect(messages.count).to eq(0)
  end

  it "refreshes the poll snapshot from a poll update" do
    message = native!(raw: "📊 **Poll:** Lunch?", poll_id: "987")
    run(
      {
        "update_id" => 4,
        "poll" => {
          "id" => "987",
          "question" => "Lunch?",
          "total_voter_count" => 3,
          "options" => [{ "text" => "Pizza", "voter_count" => 3 }],
        },
      },
    )
    expect(message.reload.raw).to include("Pizza — 3 (100%)")
    expect(message.edited_at).to be_present
  end

  describe "edited_message" do
    let!(:message) { native!(user: bot) }

    def edit_update(text: "edited!")
      update = message_update("text" => text)
      { "update_id" => 2, "edited_message" => update["message"] }
    end

    it "revises the linked native message in place" do
      run(edit_update)
      message.reload
      expect(message.raw).to eq("edited!")
      expect(message.cooked).to include("edited!")
      expect(message.edited_at).to be_present
      expect(Jobs::DisteleplusSendToTelegram.jobs).to be_empty
    end

    it "does nothing when edit bridging is off" do
      SiteSetting.disteleplus_bridge_edits = false
      run(edit_update)
      expect(message.reload.raw).to eq("earlier")
    end

    it "ignores edits of unlinked (pre-bridge) messages" do
      links.delete_all
      run(edit_update)
      expect(message.reload.raw).to eq("earlier")
    end
  end

  describe "message_reaction" do
    let!(:message) { native!(user: bot) }
    let(:reactions) { DiscourseDisteleplus::Reaction.where(message_id: message.id) }

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

    it "adds a mapped reaction as the matched user without echoing it back" do
      run(reaction_update)
      expect(reactions.pluck(:user_id, :emoji)).to eq([[user.id, "fire"]])
      expect(Jobs::DisteleplusSendToTelegram.jobs).to be_empty
    end

    it "removes reactions dropped from the new list" do
      run(reaction_update)
      run(reaction_update(old: [{ "type" => "emoji", "emoji" => "🔥" }], new: []))
      expect(reactions.count).to eq(0)
    end

    it "reacts as the bot for unmatched users" do
      run(reaction_update(user_name: "stranger"))
      expect(reactions.pluck(:user_id)).to eq([bot.id])
    end

    it "drops custom-emoji reactions" do
      run(reaction_update(new: [{ "type" => "custom_emoji", "custom_emoji_id" => "5" }]))
      expect(reactions.count).to eq(0)
    end

    it "skips unlinked messages" do
      links.delete_all
      run(reaction_update)
      expect(reactions.count).to eq(0)
    end

    it "does nothing when reaction bridging is off" do
      SiteSetting.disteleplus_bridge_reactions = false
      run(reaction_update)
      expect(reactions.count).to eq(0)
    end
  end

  it "does nothing at all when the module is disabled" do
    SiteSetting.disteleplus_enabled = false
    run(message_update)
    expect(messages.count).to eq(0)
  end
end
