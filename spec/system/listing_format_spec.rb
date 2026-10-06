# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Listing topics" do
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:buyer) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, title: "Phones and computers for sale") }
  fab!(:first_post) do
    Fabricate(:post, topic: topic, raw: "Post your listings here, one per post.")
  end
  fab!(:listing) do
    Fabricate(
      :post,
      topic: topic,
      user: seller,
      raw:
        "### ITEM\nQin F21 Pro\n\n### QUANTITY\n1\n\n### CONDITION\nLike new\n\n" \
          "### SPECS\n4GB RAM\n\n### IMAGES\nnone\n\n" \
          "### PICKUP LOCATION OR SHIPPING AVAILABLE\nPickup",
    )
  end

  before do
    SiteSetting.reqpm_enabled = true
    SiteSetting.reqpm_setup_prompt = "off"
    SiteSetting.listing_format_topics = topic.id.to_s
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    SiteSetting.min_first_post_typing_time = 0
  end

  def visit_topic
    visit("/t/#{topic.slug}/#{topic.id}")
  end

  def open_reply
    visit_topic
    find(".listing-format-create__button").click
    find(".listing-format-form")
  end

  def fill_listing(except: nil)
    find("#listing-format-item").fill_in(with: "Galaxy S10") unless except == :item
    find("#listing-format-quantity").fill_in(with: "2")
    find("#listing-format-condition-used").click
    find("#listing-format-specs").fill_in(with: "8GB RAM\n128GB")
    find("#listing-format-pickup-location-or-shipping-available-pickup").click
    find("#listing-format-pickup-location-or-shipping-available-shipping-available").click
    find("#listing-format-pickup-location-or-shipping-available").fill_in(with: "Brooklyn")
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

  it "has Create listing in place of Reply for members" do
    sign_in(buyer)
    visit_topic
    expect(page).to have_css(".listing-format-create__button", text: "Create listing")
    expect(page).to have_no_css("#topic-footer-buttons .topic-footer-main-buttons .create")
    expect(page).to have_no_css("#post_1 .post-action-menu__reply")
  end

  it "keeps Reply for staff" do
    sign_in(moderator)
    visit_topic
    expect(page).to have_css("#topic-footer-buttons .topic-footer-main-buttons .create")
    expect(page).to have_no_css(".listing-format-create")
  end

  it "keeps the form in view on a phone while the editor has focus", mobile: true do
    sign_in(buyer)
    open_reply
    find(".d-editor-input").click
    item = find("#listing-format-item")
    editor_top =
      page.evaluate_script(
        "document.querySelector('.d-editor-textarea-wrapper').getBoundingClientRect().top",
      )
    item_bottom =
      page.evaluate_script(
        "document.querySelector('#listing-format-item').getBoundingClientRect().bottom",
      )
    expect(editor_top).to be >= item_bottom
    item.fill_in(with: "Galaxy S10")
    expect(item.value).to eq("Galaxy S10")
  end

  it "leaves out REQ-PM on your own listing" do
    sign_in(seller)
    visit_topic
    expect(page).to have_css("#post_2")
    expect(page).to have_no_css("#post_2 .listing-format-reqpm")
  end

  describe "replying" do
    before { sign_in(buyer) }

    it "shows a fixed label per section, with options where there are some" do
      open_reply
      expect(all(".listing-format-form__label").map(&:text)).to eq(
        [
          "ITEM",
          "QUANTITY",
          "CONDITION",
          "SPECS",
          "IMAGES",
          "PICKUP LOCATION OR SHIPPING AVAILABLE",
        ],
      )
      expect(page).to have_css("input[type=radio]#listing-format-condition-like-new")
      expect(page).to have_css(
        "input[type=checkbox]#listing-format-pickup-location-or-shipping-available-shipping-available",
      )
      expect(find(".d-editor-input").value).to eq("")
    end

    it "asks for an empty section, then posts the listing in the thread's layout" do
      open_reply
      fill_listing(except: :item)
      find(".d-editor-input").fill_in(with: "Pictures soon")
      find(".save-or-cancel .create").click
      expect(page).to have_css(".dialog-body", text: "Fill in ITEM")
      find(".dialog-footer .btn-primary").click

      find("#listing-format-item").fill_in(with: "Galaxy S10")
      find(".save-or-cancel .create").click
      expect(page).to have_css("#post_3 .cooked h3", text: "ITEM")
      expect(Post.last.raw).to eq(<<~MD.strip)
        ### ITEM
        Galaxy S10

        ### QUANTITY
        2

        ### CONDITION
        Used

        ### SPECS
        8GB RAM
        128GB

        ### IMAGES
        Pictures soon

        ### PICKUP LOCATION OR SHIPPING AVAILABLE
        Pickup, Shipping available
        Brooklyn
      MD
    end

    it "keeps the editor's text as written when the server turns the post away" do
      open_reply
      fill_listing
      find(".d-editor-input").fill_in(with: "https://www.ebay.com/itm/123")
      find(".save-or-cancel .create").click
      expect(page).to have_css(".dialog-body", text: "www.ebay.com")
      find(".dialog-footer .btn-primary").click
      expect(find(".d-editor-input").value).to eq("https://www.ebay.com/itm/123")
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
