# frozen_string_literal: true

require "rails_helper"

# End-to-end REQ-PM in the browser: the setup prompt, asking someone for
# their details from their user card, answering from the REQ-PM page, and
# the details arriving on the other side. Set JTECH_SCREENSHOT_GALLERY=1 to
# also save screenshots (tmp/capybara/reqpm_*.png).
RSpec.describe "REQ-PM", reqpm_prompt: true do
  fab!(:alice) do
    Fabricate(:user, username: "alice_k", name: "Alice Klein", trust_level: TrustLevel[1])
  end
  fab!(:bob) do
    Fabricate(:user, username: "bob_m", name: "Bob Mizrachi", trust_level: TrustLevel[1])
  end
  fab!(:topic) { Fabricate(:topic, user: alice, title: "Looking for a good kosher flip phone") }
  fab!(:op) { Fabricate(:post, topic: topic, user: alice, raw: "Which one has the best battery?") }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.reqpm_enabled = true
    SiteSetting.hide_new_user_profiles = false
  end

  def shot(name)
    return unless ENV["JTECH_SCREENSHOT_GALLERY"]
    page.save_screenshot("reqpm_#{name}.png")
  end

  def add_method(user, kind, value, **attrs)
    method = DiscourseReqpm::ContactMethod.new(user_id: user.id, kind: kind, **attrs)
    method.value = value
    method.save!
    method
  end

  it "asks a member without details to add one, gently" do
    sign_in(bob)
    visit "/latest"

    expect(page).to have_css(".reqpm-setup-modal")
    shot("01_setup_prompt")

    find(".reqpm-kind-grid__tile[data-kind='whatsapp']").click
    find(".reqpm-method-form__value").fill_in(with: "+972 52 123 4567")
    shot("02_setup_whatsapp_form")
    find(".reqpm-method-form .btn-primary").click

    expect(page).to have_css(".reqpm-card-editor__value", text: "+972 52 123 4567")
    shot("03_setup_added")
    find(".reqpm-setup-modal .d-modal__footer .btn-primary").click
    expect(page).to have_no_css(".reqpm-setup-modal")

    visit "/latest"
    expect(page).to have_no_css(".reqpm-setup-modal")
    expect(DiscourseReqpm::ContactMethod.find_by(user_id: bob.id).value).to eq("+972 52 123 4567")
  end

  it "can be snoozed" do
    sign_in(bob)
    visit "/latest"
    find(".reqpm-setup-modal .d-modal__footer .btn-default").click
    expect(page).to have_no_css(".reqpm-setup-modal")
    expect(DiscourseReqpm::Setup.snoozed?(bob.reload)).to eq(true)
  end

  it "cannot be dismissed when required" do
    SiteSetting.reqpm_setup_prompt = "required"
    sign_in(bob)
    visit "/latest"
    expect(page).to have_css(".reqpm-setup-modal")
    expect(page).to have_no_css(".reqpm-setup-modal .modal-close")
    shot("04_setup_required")
    page.send_keys(:escape)
    expect(page).to have_css(".reqpm-setup-modal")
  end

  it "request → answer → details arrive" do
    add_method(bob, "email", "bob@example.com")
    add_method(alice, "whatsapp", "+972 52 000 1111", share_by_default: false)
    add_method(alice, "phone", "+1 718 555 0100")
    add_method(alice, "custom", "Ask for Alice at the front desk", label: "Office", emoji: "office")

    # Bob asks Alice from her user card.
    sign_in(bob)
    visit topic.url
    find("#post_1 .names a", match: :first).click
    expect(page).to have_css(".user-card .reqpm-user-button")
    shot("05_user_card_button")
    find(".user-card .reqpm-user-button").click

    expect(page).to have_css(".reqpm-user-modal")
    expect(page).to have_content("alice_k hasn't sent you any contact details yet")
    find(".reqpm-chip", text: "WhatsApp").click
    shot("06_user_modal_request")
    find(".reqpm-user-modal__request").click
    expect(page).to have_css(".reqpm-callout--success")
    expect(page).to have_css(".reqpm-status", text: "Requested")
    shot("07_user_modal_requested")

    # Alice sees the badge and answers from the REQ-PM page.
    sign_in(alice)
    visit "/latest"
    # Nothing in the header; REQ-PM sits in the avatar menu.
    expect(page).to have_no_css(".reqpm-header-icon")
    find(".header-dropdown-toggle.current-user").click
    find("#user-menu-button-profile").click
    shot("08_avatar_menu")
    find(".reqpm-menu-item a").click

    expect(page).to have_css(".reqpm-row--incoming", text: "bob_m")
    shot("09_hub_requests")
    find(".reqpm-row--incoming .reqpm-row__answer").click

    expect(page).to have_css(".reqpm-user-modal .reqpm-callout--incoming", text: "WhatsApp")
    # What Bob asked for is pre-ticked, even though it is not a default.
    whatsapp = find(".reqpm-share-list__item", text: "+972 52 000 1111")
    expect(whatsapp.find("input", visible: :all)).to be_checked
    phone = find(".reqpm-share-list__item", text: "+1 718 555 0100")
    expect(phone.find("input", visible: :all)).not_to be_checked
    shot("10_answer_modal")
    find(".reqpm-user-modal__send").click
    expect(page).to have_css(".reqpm-callout--success", text: "Sent")
    find(".reqpm-user-modal .d-modal__footer .btn-default").click

    expect(DiscourseReqpm::Request.last).to be_fulfilled

    # Bob gets exactly what Alice ticked.
    sign_in(bob)
    visit "/reqpm?tab=contacts&user=alice_k"
    card = find(".reqpm-contact-card", text: "alice_k")
    expect(card).to have_css(".reqpm-contact-list__value", text: "+972 52 000 1111")
    expect(card).to have_no_content("+1 718 555 0100")
    expect(card).to have_no_content("front desk")
    expect(card.find("a.reqpm-contact-list__go")[:href]).to eq("https://wa.me/972520001111")
    shot("11_hub_contacts")

    visit "/reqpm?tab=requests"
    expect(page).to have_css(".reqpm-state--answered")
  end

  it "shows the owner's card with custom emoji methods" do
    add_method(alice, "phone", "+1 718 555 0100", note: "Evenings only")
    add_method(alice, "custom", "Ask at the front desk", label: "Office", emoji: "office")
    sign_in(alice)
    visit "/reqpm?tab=card"
    expect(page).to have_css(".reqpm-card-editor__item", count: 2)
    expect(page).to have_css(".reqpm-kind-icon--custom img.emoji")
    shot("12_hub_my_card")

    find(".reqpm-card-editor__add").click
    expect(page).to have_css(".reqpm-kind-grid__tile", count: 9)
    shot("13_hub_add_picker")
    find(".reqpm-kind-grid__tile[data-kind='website']").click
    find(".reqpm-method-form__value").fill_in(with: "javascript:alert(1)")
    find(".reqpm-method-form .btn-primary").click
    expect(page).to have_css(".reqpm-method-form__error", text: "web address")
    shot("14_validation_error")
  end

  it "does not offer the button on your own card" do
    add_method(alice, "phone", "+1 718 555 0100")
    sign_in(alice)
    visit topic.url
    find("#post_1 .names a", match: :first).click
    expect(page).to have_css(".user-card")
    expect(page).to have_no_css(".user-card .reqpm-user-button")
  end

  it "shows REQ-PM notifications in the bell, linking to the page" do
    add_method(alice, "phone", "+1 718 555 0100")
    DiscourseReqpm::Exchange.new(bob).request!(alice, wanted_kinds: ["phone"])

    sign_in(alice)
    visit "/latest"
    find(".header-dropdown-toggle.current-user").click
    item = find(".user-menu .notification", text: "wants your contact details")
    expect(item).to have_content("bob_m")
    shot("15_bell_notification")
    item.click
    expect(page).to have_current_path(%r{/reqpm\?tab=requests})
    expect(page).to have_css(".reqpm-row--incoming", text: "bob_m")
  end

  context "on a phone-sized screen" do
    # Resized rather than `mobile: true`, which relaunches the browser.
    around { |example| resize_window(width: 390, height: 844) { example.run } }

    it "lays out the window and the page for small screens" do
      add_method(bob, "email", "bob@example.com")
      add_method(alice, "whatsapp", "+972 52 000 1111")
      DiscourseReqpm::Share.create!(
        owner_id: alice.id,
        recipient_id: bob.id,
        contact_method_id: DiscourseReqpm::ContactMethod.find_by(user_id: alice.id).id,
      )

      sign_in(bob)
      visit "/reqpm?tab=contacts"
      expect(page).to have_css(".reqpm-contact-card", text: "alice_k")
      shot("16_mobile_contacts")

      visit "/u/alice_k/summary"
      find(".reqpm-user-button").click
      expect(page).to have_css(".reqpm-user-modal .reqpm-contact-list__value", text: "+972")
      shot("17_mobile_user_modal")
    end
  end

  it "keeps your own card under Preferences → REQ-PM" do
    add_method(alice, "phone", "+1 718 555 0100")
    sign_in(alice)
    visit "/u/alice_k/preferences/account"
    find(".user-nav__preferences-reqpm a").click
    expect(page).to have_current_path("/u/alice_k/preferences/reqpm")
    expect(page).to have_css(".reqpm-card-editor__value", text: "+1 718 555 0100")
    expect(page).to have_css(".reqpm-preferences .d-toggle-switch")
    shot("18_preferences_tab")
  end

  it "treats a number saved without a country code as +1 for Call and WhatsApp" do
    # Saved before numbers were normalized on save: no country code stored.
    legacy = add_method(alice, "whatsapp", "646-820-1413")
    legacy.update_columns(
      value_ciphertext:
        DiscourseReqpm::Crypto.encrypt("646-820-1413", user_id: alice.id, field: :value),
    )
    phone = add_method(alice, "phone", "(718) 555-0100")
    DiscourseReqpm::Share.create!(
      owner_id: alice.id,
      recipient_id: bob.id,
      contact_method_id: legacy.id,
    )
    DiscourseReqpm::Share.create!(
      owner_id: alice.id,
      recipient_id: bob.id,
      contact_method_id: phone.id,
    )

    sign_in(bob)
    visit "/reqpm?tab=contacts"
    card = find(".reqpm-contact-card", text: "alice_k")
    whatsapp = card.find(".reqpm-contact-list__item", text: "646-820-1413")
    expect(whatsapp.find("a.reqpm-contact-list__go")[:href]).to eq("https://wa.me/16468201413")
    call = card.find(".reqpm-contact-list__item", text: "555-0100")
    expect(call.find("a.reqpm-contact-list__go")[:href]).to eq("tel:+17185550100")
  end

  # The forum offers Hebrew, but REQ-PM's strings are English, and a phone
  # number has nothing in it to say which way it runs: in a right-to-left
  # interface "+972 52 123 4517" read "4517 123 52 972+", and a sentence's
  # full stop came first
  it "reads contact details and its sentences the right way round in Hebrew" do
    SiteSetting.default_locale = "he"
    phone = add_method(alice, "phone", "+972 52 123 4517")
    DiscourseReqpm::Share.create!(
      owner_id: alice.id,
      recipient_id: bob.id,
      contact_method_id: phone.id,
    )
    # where a text's first and last characters start, from the left
    ends = <<~JS
      ((selector) => {
        const text = document.querySelector(selector).firstChild;
        const at = (i) => {
          const range = document.createRange();
          range.setStart(text, i);
          range.setEnd(text, i + 1);
          return Math.round(range.getBoundingClientRect().left);
        };
        return [at(0), at(text.length - 1)];
      })
    JS

    sign_in(bob)
    visit "/reqpm?tab=contacts"
    expect(page).to have_css("html.rtl .reqpm-contact-list__value", text: "123 4517")
    first, last = page.evaluate_script("#{ends}('.reqpm-contact-list__value')")
    expect(first).to be < last # the "+" first, on the left

    visit "/reqpm?tab=shared"
    expect(page).to have_css("html.rtl .reqpm-empty--big p")
    first, last = page.evaluate_script("#{ends}('.reqpm-empty--big p')")
    expect(first).to be < last # the full stop last, on the right
  end
end
