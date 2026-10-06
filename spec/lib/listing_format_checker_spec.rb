# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseListingFormat::Checker do
  let(:listing) { "Item: Qin F21 Pro\nCondition: Like new\nPrice: $80\nContact: 646-555-0134" }

  before { SiteSetting.listing_format_fields = "Item|Condition|Price|Contact" }

  def problems(raw, previous: nil)
    described_class.new(raw, previous: previous).problems
  end

  describe ".topic_ids" do
    it "reads numbers and pasted topic addresses" do
      SiteSetting.listing_format_topics =
        "32|https://jtechforums.org/t/hardware-phones-computers-for-sale-thread/32/232|/t/77/5|https://example.com/t/a-slug/90|not a topic"
      expect(described_class.topic_ids).to eq([32, 77, 90])
    end
  end

  describe "fields" do
    it "accepts a listing with every field" do
      expect(problems(listing)).to be_empty
    end

    it "accepts bold, bullets, headings, any case and a dash" do
      raw = "**Item:** Qin F21\n- condition - good\n### PRICE: $50\n__Contact__: 646-555-0134"
      expect(problems(raw)).to be_empty
    end

    it "names the fields that are missing or left empty" do
      raw = "Item: Qin F21\nCondition: good\nPrice:\n"
      expect(described_class.new(raw).missing_fields).to eq(%w[Price Contact])
      expect(problems(raw).first).to include("Price, Contact")
    end

    it "doesn't count fields inside a quote" do
      raw = "[quote=\"seller, post:2, topic:1\"]\n#{listing}\n[/quote]\nStill available?"
      expect(described_class.new(raw).missing_fields).to eq(%w[Item Condition Price Contact])

      quoted = listing.lines.map { |line| "> #{line}" }.join
      expect(described_class.new("#{quoted}\n\nInterested").missing_fields.size).to eq(4)
    end
  end

  describe "links" do
    it "turns away links to other sites, however they're written" do
      [
        "https://www.ebay.com/itm/123",
        "[my listing](https://www.ebay.com/itm/123)",
        "<a href=\"https://www.ebay.com/itm/123\">here</a>",
        "see ebay.com/itm/123",
        "on www.yad2.co.il",
      ].each do |link|
        expect(problems("#{listing}\n\n#{link}").last).to include("Links to other sites"), link
      end
    end

    it "names the site" do
      expect(problems("#{listing}\nhttps://www.ebay.com/itm/123").last).to include("www.ebay.com")
    end

    it "allows email addresses, phone numbers and the forum itself" do
      raw = <<~MD
        #{listing}
        Email me at seller@gmail.com or [here](mailto:seller@gmail.com), call [646-555-0134](tel:+16465550134).
        Pictures: #{Discourse.base_url}/t/photos/123 and [this](/t/photos/123), version 2.0, @someone
        ![phone](/uploads/default/original/1X/abc.png)
      MD
      expect(problems(raw)).to be_empty
    end

    it "lets links through when blocking is off" do
      SiteSetting.listing_format_block_links = false
      expect(problems("#{listing}\nhttps://www.ebay.com/itm/123")).to be_empty
    end
  end

  describe "edits" do
    let(:old_post) { "Anyone selling a Qin?\nhttps://www.ebay.com/itm/123" }

    it "lets an older post be edited without adding the fields" do
      expect(problems("Anyone selling a Qin? (sold)", previous: old_post)).to be_empty
    end

    it "keeps a link the post already had" do
      expect(problems("#{old_post}\nThanks", previous: old_post)).to be_empty
    end

    it "turns away a link the edit adds" do
      edited = "#{old_post}\nhttps://www.amazon.com/dp/1"
      expect(problems(edited, previous: old_post).join).to include("www.amazon.com")
      expect(problems(edited, previous: old_post).join).not_to include("www.ebay.com")
    end

    it "turns away an edit that takes out a field the post had" do
      edited = listing.sub("Price: $80\n", "")
      expect(problems(edited, previous: listing).join).to include("Price")
    end
  end
end
