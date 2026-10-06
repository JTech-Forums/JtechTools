# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseListingFormat::Checker do
  # The sale thread's own layout.
  let(:listing) { <<~MD }
      ### ITEM
      Qin F21 Pro

      ### QUANTITY
      1

      ### CONDITION
      Like new

      ### SPECS
      4GB RAM
      64GB storage

      ### IMAGES
      ![phone](/uploads/default/original/1X/abc.png)

      ### PICKUP LOCATION OR SHIPPING AVAILABLE
      Pickup, Shipping available
    MD

  def problems(raw, previous: nil)
    described_class.new(raw, previous: previous).problems
  end

  def missing(raw)
    described_class.missing_fields_in(raw)
  end

  describe ".topic_ids" do
    it "reads numbers and pasted topic addresses" do
      SiteSetting.listing_format_topics =
        "32|https://jtechforums.org/t/hardware-phones-computers-for-sale-thread/32/232|/t/77/5|https://example.com/t/a-slug/90|not a topic"
      expect(described_class.topic_ids).to eq([32, 77, 90])
    end
  end

  describe ".choices" do
    it "reads the options for sections that are fields, matching any case" do
      SiteSetting.listing_format_single_choice = "condition: New, Used|COLOR: Red, Blue"
      SiteSetting.listing_format_multiple_choice =
        "PICKUP LOCATION OR SHIPPING AVAILABLE: Pickup, Shipping available"
      expect(described_class.choices).to eq(
        "CONDITION" => {
          multiple: false,
          options: %w[New Used],
        },
        "PICKUP LOCATION OR SHIPPING AVAILABLE" => {
          multiple: true,
          options: ["Pickup", "Shipping available"],
        },
      )
    end
  end

  describe ".editor_field" do
    it "is the matching field, or nil when it isn't one" do
      SiteSetting.listing_format_editor_field = "images"
      expect(described_class.editor_field).to eq("IMAGES")

      SiteSetting.listing_format_editor_field = "PHOTOS"
      expect(described_class.editor_field).to be_nil
    end
  end

  describe "sections" do
    it "accepts a listing in the thread's layout" do
      expect(problems(listing)).to be_empty
    end

    it "accepts other headings, bold names and one-line sections, in any case" do
      raw = <<~MD
        ## Item
        Qin F21
        **Quantity:** 2
        - condition - good
        __SPECS__
        4GB
        # images
        none yet
        Pickup location or shipping available: pickup in Brooklyn
      MD
      expect(missing(raw)).to be_empty
    end

    it "names the sections that are missing or have nothing under them" do
      raw = listing.sub("Like new\n", "").sub(/### SPECS.*?\n\n/m, "")
      expect(missing(raw)).to eq(%w[CONDITION SPECS])
      expect(problems(raw).first).to include("CONDITION, SPECS")
      expect(problems(raw).first).to include("### CONDITION")
    end

    it "doesn't take a sentence that starts with a section's name for it" do
      raw = listing.sub("### ITEM\nQin F21 Pro\n", "Item is a Qin F21 Pro\n")
      expect(missing(raw)).to eq(%w[ITEM])
    end

    it "doesn't count sections inside a quote" do
      raw = "[quote=\"seller, post:2, topic:1\"]\n#{listing}\n[/quote]\nStill available?"
      expect(missing(raw).size).to eq(6)

      quoted = listing.lines.map { |line| "> #{line}" }.join
      expect(missing("#{quoted}\n\nInterested").size).to eq(6)
    end

    it "turns away a comment" do
      expect(problems("Is this still available?").first).to include("missing: ITEM")
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
        expect(problems("#{listing}\n#{link}").last).to include("Links to other sites"), link
      end
    end

    it "names the site" do
      expect(problems("#{listing}\nhttps://www.ebay.com/itm/123").last).to include("www.ebay.com")
    end

    it "allows email addresses, phone numbers and the forum itself" do
      raw = <<~MD
        #{listing}
        Email me at seller@gmail.com or [here](mailto:seller@gmail.com), call [646-555-0134](tel:+16465550134).
        More at #{Discourse.base_url}/t/photos/123 and [this](/t/photos/123), version 2.0
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

    it "lets an older post be edited without adding the sections" do
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

    it "turns away an edit that empties a section the post had" do
      edited = listing.sub("Like new\n", "")
      expect(problems(edited, previous: listing).join).to include("CONDITION")
    end
  end
end
