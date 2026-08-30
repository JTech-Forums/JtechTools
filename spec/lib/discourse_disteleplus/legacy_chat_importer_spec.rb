# frozen_string_literal: true

require "rails_helper"

# The importer is the only code allowed to touch Discourse Chat. It skips
# when Chat is not loaded (a bare core checkout) rather than faking it.
RSpec.describe DiscourseDisteleplus::LegacyChatImporter do
  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
  end

  describe "without Discourse Chat or a legacy channel" do
    it "reports unavailable and refuses to import" do
      SiteSetting.disteleplus_chat_channel_id = 0
      status = described_class.status
      expect(status[:available]).to eq(false)
      expect(status[:complete]).to eq(false)
      expect(status[:imported]).to eq(0)
      expect { described_class.import_batch }.to raise_error(RuntimeError)
    end
  end

  describe "with Discourse Chat" do
    fab!(:author, :user)
    fab!(:bot) { Fabricate(:user, username: "telegram_bridge") }

    before do
      skip "chat plugin not loaded" unless defined?(::Chat::Message)
      SiteSetting.chat_enabled = true
      @channel = Fabricate(:category_channel)
      allow(SiteSetting).to receive(:disteleplus_chat_channel_id).and_return(@channel.id)
    end

    def legacy!(message, user: author, **opts)
      Fabricate(:chat_message, chat_channel: @channel, user: user, message: message, **opts)
    end

    it "imports messages, replies, prefixes, and relinks Telegram rows idempotently" do
      parent = legacy!("first")
      tg = legacy!("**Zev (TG):** hello", user: bot)
      DiscourseDisteleplus::MessageLink.create!(
        telegram_chat_id: -1,
        telegram_message_id: 5,
        chat_message_id: tg.id,
        direction: :tg_to_discourse,
      )
      child = legacy!("reply", in_reply_to_id: parent.id)

      result = described_class.import_batch(after_id: 0, batch_size: 10)
      expect(result[:imported]).to eq(3)
      expect(result[:more]).to eq(false)

      native_parent = DiscourseDisteleplus::Message.find_by(legacy_chat_message_id: parent.id)
      native_tg = DiscourseDisteleplus::Message.find_by(legacy_chat_message_id: tg.id)
      native_child = DiscourseDisteleplus::Message.find_by(legacy_chat_message_id: child.id)
      expect(native_parent.user).to eq(author)
      expect(native_tg).to be_source_telegram
      expect(native_tg.external_sender_name).to eq("Zev")
      expect(native_tg.raw).to eq("hello")
      expect(native_child.reply_to).to eq(native_parent)
      expect(DiscourseDisteleplus::MessageLink.last.disteleplus_message_id).to eq(native_tg.id)

      expect(described_class.import_batch(after_id: 0)[:imported]).to eq(0)
      expect(DiscourseDisteleplus::Message.count).to eq(3)

      status = described_class.status
      expect(status).to include(
        source: 3,
        imported: 3,
        remaining: 0,
        complete: true,
        linked_telegram: 1,
      )
    end
  end
end
