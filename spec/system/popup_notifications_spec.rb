# frozen_string_literal: true

require "rails_helper"

# End-to-end coverage for the desktop pop-up notification toast, plus proof
# that it is PURELY ADDITIVE:
#
#   * OFF (the default): a new reply still creates the normal `replied`
#     notification (bell/dropdown unchanged) and NO toast appears.
#   * ON: the same reply creates the same notification AND additionally pops
#     the toast. Clicking the toast routes to the post (like the dropdown
#     row); clicking elsewhere dismisses it.
#
# Screenshots of both states are captured for UI/UX review; they land in
# tmp/capybara/ and are published as the CI artifact.
RSpec.describe "Desktop pop-up notifications", type: :system do
  fab!(:author) { Fabricate(:user, username: "poster_pat") }
  fab!(:recipient) { Fabricate(:user, username: "reader_rhea") }
  fab!(:category)
  fab!(:topic) do
    Fabricate(
      :topic,
      category: category,
      user: recipient,
      title: "Might be the next Qin but better",
    )
  end
  fab!(:op) do
    Fabricate(:post, topic: topic, user: recipient, raw: "What do you all think of this phone?")
  end

  let(:user_field) { DiscoursePopupNotifications::USER_ENABLED_FIELD }

  before do
    SiteSetting.popup_notifications_enabled = true
    SiteSetting.auto_silence_fast_typers_on_first_post = false
  end

  def shot(name)
    page.save_screenshot("#{name}.png")
  rescue StandardError
    # Never fail the spec over a screenshot.
  end

  def set_pref(value)
    recipient.custom_fields[user_field] = value
    recipient.save_custom_fields(true)
  end

  # A reply BY author TO the recipient's opening post → core creates a
  # `replied` notification for recipient and publishes it on
  # /notification/:id (the channel the toast subscribes to).
  def reply_to_recipient!
    PostCreator.create!(
      author,
      topic_id: topic.id,
      raw:
        "Excellent screen quality. Supports 4g volte in Israel with excellent cellular reception.",
      reply_to_post_number: op.post_number,
    )
  end

  def replied_notification_exists?
    Notification.exists?(user_id: recipient.id, notification_type: Notification.types[:replied])
  end

  it "off (default): normal notification fires, no toast appears" do
    set_pref(false)
    sign_in(recipient)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#post_1", wait: 10)

    reply_to_recipient!

    # Core notification is created exactly as before — nothing changed.
    expect(replied_notification_exists?).to eq(true)
    # ...but the additive toast never appears.
    expect(page).to have_no_css(".jtech-popup-toast", wait: 5)
    shot("popup_notifications_off")
  end

  it "on: the same notification also pops the additive toast" do
    set_pref(true)
    sign_in(recipient)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#post_1", wait: 10)

    reply_to_recipient!

    # The toast appears, laid out name → avatar → bold title → message.
    expect(page).to have_css(".jtech-popup-toast", wait: 10)
    expect(page).to have_css(".jtech-popup-toast__username", text: "poster_pat")
    expect(page).to have_css(".jtech-popup-toast__title", text: topic.title)
    shot("popup_notifications_on")

    # Core notifications still work — the bell is present and the row exists.
    expect(replied_notification_exists?).to eq(true)
    expect(page).to have_css(".header-dropdown-toggle.current-user")

    # Clicking the toast routes to the replied post, like the dropdown row.
    find(".jtech-popup-toast").click
    expect(page).to have_css("#post_2", wait: 10)
    expect(page).to have_no_css(".jtech-popup-toast")
  end

  it "dismisses when clicking anywhere else" do
    set_pref(true)
    sign_in(recipient)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#post_1", wait: 10)

    reply_to_recipient!
    expect(page).to have_css(".jtech-popup-toast", wait: 10)

    # A click outside the card (on the opening post) dismisses it.
    find("#post_1 .cooked").click
    expect(page).to have_no_css(".jtech-popup-toast")
  end
end
