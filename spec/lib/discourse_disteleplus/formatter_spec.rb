# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::Formatter do
  describe ".inbound_text" do
    let(:msg) { { "text" => "hello", "from" => { "first_name" => "Zev", "last_name" => "K" } } }

    it "passes matched senders' text through untouched" do
      expect(described_class.inbound_text(msg, matched: true)).to eq("hello")
    end

    it "prefixes unmatched senders with their display name" do
      expect(described_class.inbound_text(msg, matched: false)).to eq("**Zev K (TG):** hello")
    end

    it "falls back to caption for media messages" do
      expect(described_class.inbound_text({ "caption" => "pic!" }, matched: true)).to eq("pic!")
    end
  end

  describe ".sender_display_name" do
    it "prefers first + last name" do
      expect(described_class.sender_display_name("first_name" => "A", "last_name" => "B")).to eq(
        "A B",
      )
    end

    it "falls back to @username, then the id" do
      expect(described_class.sender_display_name("username" => "zk")).to eq("@zk")
      expect(described_class.sender_display_name("id" => 5)).to eq("Telegram user 5")
    end
  end

  describe ".outbound_html" do
    it "bolds the author and escapes the body" do
      expect(described_class.outbound_html("zev", "a <b> & c")).to eq(
        "<b>zev:</b> a &lt;b&gt; &amp; c",
      )
    end

    it "handles empty bodies" do
      expect(described_class.outbound_html("zev", "")).to eq("<b>zev</b>")
    end

    it "converts emoji shortcodes to unicode for Telegram" do
      expect(described_class.outbound_html("zev", "nice :grin:")).to eq("<b>zev:</b> nice 😁")
    end

    it "collapses quote blocks to a username attribution" do
      raw = "[quote=\"Zev K, post:3, topic:9, username:zev\"]their\nbio and stuff[/quote]\nagreed"
      expect(described_class.outbound_html("bob", raw)).to eq("<b>bob:</b> ↩︎ Zev K\nagreed")
    end

    it "collapses nested and bare quote blocks" do
      raw = "[quote][quote=\"a\"]x[/quote]y[/quote]\nz"
      expect(described_class.outbound_html("bob", raw)).to eq("<b>bob:</b> ↩︎\nz")
    end

    it "converts basic markdown to Telegram HTML entities" do
      expect(described_class.outbound_html("z", "**b** *i* `c` [l](https://x.y)")).to eq(
        "<b>z:</b> <b>b</b> <i>i</i> <code>c</code> <a href=\"https://x.y\">l</a>",
      )
    end

    it "leaves ambiguous asterisks alone" do
      expect(described_class.outbound_html("z", "2 * 3 * 4")).to eq("<b>z:</b> 2 * 3 * 4")
    end

    it "names inline uploads instead of leaking upload:// markdown" do
      expect(described_class.outbound_html("z", "![pic.png](upload://abc.png)")).to eq(
        "<b>z:</b> 📎 pic.png",
      )
    end

    it "links a bold display name on its own line when given a profile url" do
      expect(
        described_class.outbound_html(
          "zev",
          "hi <3",
          display_name: "Zev K",
          profile_url: "https://f/u/zev",
        ),
      ).to eq("<a href=\"https://f/u/zev\"><b>Zev K</b></a>\nhi &lt;3")
      expect(described_class.outbound_html("zev", "", profile_url: "https://f/u/zev")).to eq(
        "<a href=\"https://f/u/zev\"><b>zev</b></a>",
      )
    end
  end

  describe ".poll_markdown" do
    let(:poll) do
      {
        "question" => "Lunch?",
        "total_voter_count" => 4,
        "is_anonymous" => true,
        "options" => [
          { "text" => "Pizza", "voter_count" => 3 },
          { "text" => "Salad", "voter_count" => 1 },
        ],
      }
    end

    it "renders question, options, percentages and meta" do
      md = described_class.poll_markdown(poll)
      expect(md).to include("📊 **Poll:** Lunch?")
      expect(md).to include("- Pizza — 3 (75%)")
      expect(md).to include("- Salad — 1 (25%)")
      expect(md).to include("4 votes · anonymous")
    end

    it "marks closed polls" do
      expect(described_class.poll_markdown(poll.merge("is_closed" => true))).to include("closed")
    end

    it "survives zero voters" do
      md = described_class.poll_markdown(poll.merge("total_voter_count" => 0))
      expect(md).to include("(0%)")
    end
  end

  describe ".media_placeholder" do
    it "includes the size when known" do
      expect(described_class.media_placeholder("video", size_bytes: 25 * 1024 * 1024)).to eq(
        "📎 video (25.0 MB) — too large to bridge",
      )
    end

    it "degrades without a size" do
      expect(described_class.media_placeholder("sticker")).to eq("📎 sticker — could not be bridged")
    end
  end
end
