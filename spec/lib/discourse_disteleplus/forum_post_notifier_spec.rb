# frozen_string_literal: true

require "rails_helper"

# Forum post → Telegram announcements: eligibility rules, message shape, the
# delivery job (Telegram + native mirror, idempotent), and the health record
# that feeds the dashboard problem check.
RSpec.describe DiscourseDisteleplus::ForumPostNotifier do
  fab!(:category)
  fab!(:secret_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:author) { Fabricate(:user, username: "poster", name: "Poster Person") }
  fab!(:topic) { Fabricate(:topic, category: category, title: "Deploy window & <plans>") }
  fab!(:post) { Fabricate(:post, topic: topic, user: author, raw: "We deploy at **14:00** today.") }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_forum_post_notifications_enabled = true
    SiteSetting.disteleplus_telegram_chat_id = "-100555"
    SiteSetting.disteleplus_bridge_bot_username = "telegram_bridge"
  end

  describe ".eligible?" do
    it "accepts a public first post" do
      expect(described_class.eligible?(post)).to eq(true)
    end

    it "is off by default and respects the master switch" do
      SiteSetting.disteleplus_forum_post_notifications_enabled = false
      expect(described_class.eligible?(post)).to eq(false)
    end

    it "skips replies when first-post-only is on, accepts them otherwise" do
      reply = Fabricate(:post, topic: topic, user: author)
      expect(described_class.eligible?(reply)).to eq(false)
      SiteSetting.disteleplus_forum_post_first_post_only = false
      expect(described_class.eligible?(reply)).to eq(true)
    end

    it "never announces private messages, restricted categories, whispers or hidden posts" do
      pm = Fabricate(:private_message_post, user: author)
      expect(described_class.eligible?(pm)).to eq(false)
      secret = Fabricate(:post, topic: Fabricate(:topic, category: secret_category), user: author)
      expect(described_class.eligible?(secret)).to eq(false)
      whisper = Fabricate(:post, topic: topic, user: author, post_type: Post.types[:whisper])
      expect(described_class.eligible?(whisper)).to eq(false)
      post.update!(hidden: true)
      expect(described_class.eligible?(post)).to eq(false)
    end

    it "filters by category (including parent) and tags" do
      other = Fabricate(:category)
      SiteSetting.disteleplus_forum_post_categories = other.id.to_s
      expect(described_class.eligible?(post)).to eq(false)
      SiteSetting.disteleplus_forum_post_categories = category.id.to_s
      expect(described_class.eligible?(post)).to eq(true)

      SiteSetting.disteleplus_forum_post_tags = "ops"
      expect(described_class.eligible?(post)).to eq(false)
      topic.tags << Fabricate(:tag, name: "ops")
      expect(described_class.eligible?(post.reload)).to eq(true)
    end
  end

  describe "message text" do
    it "escapes HTML and links the topic" do
      html = described_class.telegram_html(post)
      expect(html).to include("<b>Poster Person</b> posted")
      expect(html).to include("Deploy window &amp; &lt;plans&gt;")
      expect(html).to include(post.full_url)
      expect(html).to include("<blockquote>We deploy at 14:00 today.</blockquote>")
    end

    it "sends title only when the excerpt length is zero" do
      SiteSetting.disteleplus_forum_post_excerpt_length = 0
      expect(described_class.telegram_html(post)).not_to include("blockquote")
    end
  end

  describe Jobs::DisteleplusNotifyForumPost do
    let(:api) { instance_double(DiscourseDisteleplus::TelegramApi) }
    let(:ok) do
      DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "message_id" => 77 })
    end
    let(:failed) do
      DiscourseDisteleplus::TelegramApi::Result.new(
        ok: false,
        description: "Bad Request: chat not found",
      )
    end

    before { allow(DiscourseDisteleplus::TelegramApi).to receive(:new).and_return(api) }

    it "sends to the conversation topic and mirrors a native bot message once" do
      SiteSetting.disteleplus_chat_topic_id = 42
      allow(api).to receive(:call).and_return(ok)

      described_class.new.execute(post_id: post.id)
      described_class.new.execute(post_id: post.id)

      expect(api).to have_received(:call).once.with(
        "sendMessage",
        a_hash_including(
          chat_id: "-100555",
          message_thread_id: 42,
          parse_mode: "HTML",
          disable_web_page_preview: true,
        ),
      )
      message = DiscourseDisteleplus::Message.last
      expect(message.user).to eq(DiscourseDisteleplus.bot_user)
      expect(message.raw).to include("**@poster** posted [Deploy window & <plans>](")
      expect(DiscourseDisteleplus::MessageLink.last).to have_attributes(
        telegram_message_id: 77,
        disteleplus_message_id: message.id,
      )
      expect(Jobs::DisteleplusSendToTelegram.jobs).to be_empty
    end

    it "records a health error on failure and creates nothing" do
      allow(api).to receive(:call).and_return(failed)
      described_class.new.execute(post_id: post.id)
      expect(DiscourseDisteleplus::Message.count).to eq(0)
      expect(DiscourseDisteleplus::Health.last_error["description"]).to include("chat not found")
    end

    it "is enqueued from post_created for eligible posts" do
      fresh = Fabricate(:post, topic: Fabricate(:topic, category: category), user: author)
      expect_enqueued_with(job: :disteleplus_notify_forum_post, args: { post_id: fresh.id }) do
        DiscourseEvent.trigger(:post_created, fresh, {}, author)
      end
    end
  end

  describe DiscourseDisteleplus::Health do
    it "keeps the last error for a day and maps hints" do
      described_class.record_error("Forbidden: bot was kicked from the supergroup chat")
      expect(described_class.last_error["description"]).to include("Forbidden")
      expect(described_class.error_key_for(described_class.last_error["description"])).to eq(
        "forbidden",
      )
      expect(described_class.error_key_for("Bad Request: chat not found")).to eq("chat_not_found")
      described_class.clear!
      expect(described_class.last_error).to be_nil
    end
  end

  describe ProblemCheck::DisteleplusTelegram do
    it "reports a problem only while a recent error exists" do
      expect(described_class.new.call).to be_blank
      DiscourseDisteleplus::Health.record_error("Bad Request: chat not found")
      problems = Array(described_class.new.call)
      expect(problems.length).to eq(1)
      expect(problems.first.details[:hint]).to include("chat id")
    end
  end

  describe Jobs::DisteleplusSendTestMessage do
    let(:api) { instance_double(DiscourseDisteleplus::TelegramApi) }

    before { allow(DiscourseDisteleplus::TelegramApi).to receive(:new).and_return(api) }

    it "sends the test message and clears a previous error on success" do
      DiscourseDisteleplus::Health.record_error("old")
      allow(api).to receive(:call).and_return(
        DiscourseDisteleplus::TelegramApi::Result.new(ok: true, result: { "message_id" => 1 }),
      )
      described_class.new.execute({})
      expect(api).to have_received(:call).with("sendMessage", a_hash_including(chat_id: "-100555"))
      expect(DiscourseDisteleplus::Health.last_error).to be_nil
    end

    it "records the failure" do
      allow(api).to receive(:call).and_return(
        DiscourseDisteleplus::TelegramApi::Result.new(
          ok: false,
          description: "Forbidden: bot is not a member",
        ),
      )
      described_class.new.execute({})
      expect(DiscourseDisteleplus::Health.last_error["description"]).to include("Forbidden")
    end

    it "is triggered by the admin toggle, which resets itself" do
      expect_enqueued_with(job: :disteleplus_send_test_message) do
        SiteSetting.disteleplus_send_test_message_now = true
      end
      expect(SiteSetting.disteleplus_send_test_message_now).to eq(false)
    end
  end
end
