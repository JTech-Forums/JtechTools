# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Listing topics" do
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:buyer) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, title: "Phones and computers for sale") }
  fab!(:first_post) { Fabricate(:post, topic: topic, raw: "Post your listings here, one per post.") }
  fab!(:listing) do
    Fabricate(
      :post,
      topic: topic,
      user: seller,
      raw: "Item: Qin F21 Pro\nCondition: Like new\nPrice: $80",
    )
  end

  before do
    SiteSetting.reqpm_enabled = true
    SiteSetting.reqpm_setup_prompt = "off"
    SiteSetting.listing_format_fields = "Item|Condition|Price"
    SiteSetting.listing_format_topics = topic.id.to_s
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    SiteSetting.min_first_post_typing_time = 0
  end

  def visit_topic
    visit("/t/#{topic.slug}/#{topic.id}")
  end

  def open_reply
    visit_topic
    find("#topic-footer-buttons .create", match: :first).click
    find(".listing-format-form")
  end

  describe "a listing" do
    before { sign_in(buyer) }

    it "has the seller's REQ-PM button instead of Reply" do
      visit_topic
      within("#post_2") do
        expect(page).to have_css(".listing-format-reqpm")
        expect(page).to have_no_css(".post-action-menu__reply, .reply")
      end
    end

    it "opens the seller's REQ-PM window" do
      visit_topic
      within("#post_2") { find(".listing-format-reqpm").click }
      expect(page).to have_css(".reqpm-user-modal", text: seller.username)
    end
  end

  it "leaves out REQ-PM on your own listing" do
    sign_in(seller)
    visit_topic
    expect(page).to have_css("#post_2")
    expect(page).to have_no_css("#post_2 .listing-format-reqpm")
  end

  describe "replying" do
    before { sign_in(buyer) }

    it "shows a fixed label for each field above the editor" do
      open_reply
      labels = all(".listing-format-form__label").map(&:text)
      expect(labels).to eq(%w[Item Condition Price])
      expect(find(".d-editor-input").value).to eq("")
    end

    it "asks for a field left empty, then posts the listing" do
      open_reply
      find("#listing-format-item").fill_in(with: "Galaxy S10")
      find("#listing-format-condition").fill_in(with: "Good")
      find(".d-editor-input").fill_in(with: "Comes with a case.")
      find(".save-or-cancel .create").click
      expect(page).to have_css(".dialog-body", text: "Fill in Price")
      find(".dialog-footer .btn-primary").click

      find("#listing-format-price").fill_in(with: "$120")
      find(".save-or-cancel .create").click
      expect(page).to have_css("#post_3 .cooked", text: "Price: $120")
      expect(Post.last.raw).to eq(
        "Item: Galaxy S10\nCondition: Good\nPrice: $120\n\nComes with a case.",
      )
    end

    it "keeps the editor's text as written when the server turns the post away" do
      open_reply
      find("#listing-format-item").fill_in(with: "Galaxy S10")
      find("#listing-format-condition").fill_in(with: "Good")
      find("#listing-format-price").fill_in(with: "$120")
      find(".d-editor-input").fill_in(with: "Pictures at https://www.ebay.com/itm/123")
      find(".save-or-cancel .create").click
      expect(page).to have_css(".dialog-body", text: "www.ebay.com")
      find(".dialog-footer .btn-primary").click
      expect(find(".d-editor-input").value).to eq("Pictures at https://www.ebay.com/itm/123")
    end
  end

  it "keeps the plain composer in other topics" do
    sign_in(buyer)
    SiteSetting.listing_format_topics = ""
    visit_topic
    find("#topic-footer-buttons .create", match: :first).click
    expect(page).to have_css(".d-editor-input")
    expect(page).to have_no_css(".listing-format-form")
  end
end
