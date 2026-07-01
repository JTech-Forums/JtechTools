# frozen_string_literal: true

require "rails_helper"

# Behavioral coverage for the desktop pop-up notification toast.
#
# The toast is PURELY ADDITIVE: it subscribes to the same
# `/notification/:id` MessageBus channel core already publishes on and
# renders a card — it never touches core notification code, the bell, the
# dropdown, or read-state. So "regular notifications are unchanged" holds by
# construction; these examples prove the toast itself:
#
#   * OFF (the default): a published notification produces NO toast.
#   * ON: the same notification pops the toast (name + action + title), and
#     clicking it routes to the post like the dropdown row.
#   * Clicking elsewhere dismisses it.
#
# Each example loads the page fresh and publishes exactly one crafted
# notification on the channel — the same delivery core uses — which is the
# reliable path in the parallel system-test runner (a real reply would rely
# on PostAlerter running inline, which it does not here).
RSpec.describe "Desktop pop-up notifications" do
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
  fab!(:reply_post) do
    Fabricate(
      :post,
      topic: topic,
      user: author,
      raw:
        "Excellent screen quality. Supports 4g volte in Israel with excellent cellular reception.",
    )
  end

  let(:user_field) { DiscoursePopupNotifications::USER_ENABLED_FIELD }

  before do
    SiteSetting.popup_notifications_enabled = true
    SiteSetting.popup_notifications_timeout_seconds = 300
    SiteSetting.auto_silence_fast_typers_on_first_post = false
  end

  def set_pref(value)
    recipient.custom_fields[user_field] = value
    recipient.save_custom_fields(true)
  end

  # Publish a reply-shaped notification for the recipient — the browser is
  # subscribed to this channel, so the toast renders it.
  def publish_reply
    MessageBus.publish(
      "/notification/#{recipient.id}",
      {
        unread_notifications: 1,
        all_unread_notifications_count: 1,
        last_notification: {
          notification: {
            id: 900_001,
            user_id: recipient.id,
            notification_type: Notification.types[:replied],
            read: false,
            created_at: Time.zone.now.iso8601,
            topic_id: topic.id,
            post_number: reply_post.post_number,
            slug: topic.slug,
            fancy_title: topic.fancy_title,
            data: {
              display_username: author.username,
              topic_title: topic.title,
              original_post_id: reply_post.id,
            },
          },
        },
      },
      user_ids: [recipient.id],
    )
  end

  def open_topic
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#post_1", wait: 10)
  end

  # Re-publish (fresh id each time) until the toast appears, in case the
  # browser's MessageBus poll is not yet listening when the first publish
  # lands.
  def publish_reply_until_toast
    8.times do
      publish_reply
      return if page.has_css?(".jtech-popup-toast", wait: 1.5)
    end
    expect(page).to have_css(".jtech-popup-toast", wait: 5)
  end

  it "pops the toast when the preference is on" do
    set_pref(true)
    sign_in(recipient)
    open_topic

    publish_reply_until_toast

    expect(page).to have_css(".jtech-popup-toast__name", text: author.username)
    expect(page).to have_css(".jtech-popup-toast__action", text: "Replied")
    expect(page).to have_css(".jtech-popup-toast__title", text: topic.title)

    # Clicking the toast routes to the replied post, like the dropdown row.
    find(".jtech-popup-toast").click
    expect(page).to have_css("#post_#{reply_post.post_number}", wait: 10)
    expect(page).to have_no_css(".jtech-popup-toast")
  end

  it "does not pop the toast when the preference is off (the default)" do
    set_pref(false)
    sign_in(recipient)
    open_topic

    publish_reply

    expect(page).to have_no_css(".jtech-popup-toast", wait: 5)
  end

  it "dismisses when clicking anywhere else" do
    set_pref(true)
    sign_in(recipient)
    open_topic

    publish_reply_until_toast

    find("#post_1 .cooked").click
    expect(page).to have_no_css(".jtech-popup-toast")
  end
end
