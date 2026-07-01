# frozen_string_literal: true

require "rails_helper"

# Screenshot gallery for the desktop pop-up notification feature — 15 shots
# across the two surfaces the user interacts with:
#
#   * the account page where the preference is set (shots 01–04), plus the
#     admin master switch (05) and the control hidden when the master is off
#     (06); and
#   * the page where the notification arrives — the toast itself, across
#     notification types and content shapes (07–15).
#
# The toast shots drive the card by publishing crafted notifications on the
# user's `/notification/:id` MessageBus channel (the same channel core uses),
# which is fast and lets each shot pin an exact visual state. The REAL
# end-to-end path (a live reply → toast) is proven separately in
# spec/system/popup_notifications_spec.rb.
#
# Screenshots land in tmp/capybara/ and are published as the CI artifact.
RSpec.describe "Desktop pop-up notification screenshots" do
  fab!(:author) { Fabricate(:user, username: "poster_pat", name: "Pat Poster") }
  fab!(:recipient) { Fabricate(:user, username: "reader_rhea") }
  fab!(:admin) { Fabricate(:admin, username: "admin_amy") }
  fab!(:category) { Fabricate(:category, name: "Flip phones") }
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
  fab!(:long_reply) do
    Fabricate(
      :post,
      topic: topic,
      user: author,
      raw:
        "Honestly this might be the best budget option out there right now — the build feels " \
          "premium, the screen is bright even outdoors, calls are crystal clear on 4G VoLTE, and " \
          "the battery genuinely lasts a day and a half of heavy use without needing a top-up.",
    )
  end
  fab!(:long_topic) do
    Fabricate(
      :topic,
      category: category,
      user: recipient,
      title:
        "A remarkably and unnecessarily long topic title that should be truncated with an " \
          "ellipsis inside the pop-up card so it never wraps onto a second line",
    )
  end
  fab!(:long_topic_reply) do
    Fabricate(:post, topic: long_topic, user: author, raw: "See the specs I linked above.")
  end

  let(:user_field) { DiscoursePopupNotifications::USER_ENABLED_FIELD }
  # Mutable memoized counter (avoids an instance variable in the helper) so
  # every crafted notification gets a fresh id and dedupe never suppresses it.
  let(:id_seq) { [500_000] }

  before do
    SiteSetting.popup_notifications_enabled = true
    SiteSetting.popup_notifications_timeout_seconds = 300 # keep the card up long enough to shoot
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    recipient.custom_fields[user_field] = true
    recipient.save_custom_fields(true)
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
      # Capture anyway rather than fail over a slow avatar image.
    end
    page.save_screenshot("popup_notifications_#{name}.png")
  end

  # Publish a crafted notification on the recipient's channel — the browser is
  # subscribed, so the toast renders it. Each call uses a fresh id so the
  # component's dedupe never suppresses it.
  def push(type:, data:, topic_id: nil, post_number: nil, fancy_title: nil, slug: nil)
    id_seq[0] += 1
    payload = {
      unread_notifications: 1,
      all_unread_notifications_count: 1,
      last_notification: {
        notification: {
          id: id_seq[0],
          user_id: recipient.id,
          notification_type: Notification.types[type],
          read: false,
          high_priority: false,
          created_at: Time.zone.now.iso8601,
          post_number: post_number,
          topic_id: topic_id,
          fancy_title: fancy_title,
          slug: slug,
          data: data,
        },
      },
    }
    MessageBus.publish("/notification/#{recipient.id}", payload, user_ids: [recipient.id])
  end

  # A reply-shaped notification that enriches from a real post (avatar + body
  # excerpt), varying only the type so each screenshot is a distinct kind.
  def push_from_post(type:, post:, into: topic)
    push(
      type: type,
      topic_id: into.id,
      post_number: post.post_number,
      slug: into.slug,
      fancy_title: into.fancy_title,
      data: {
        display_username: post.user.username,
        topic_title: into.title,
        original_post_id: post.id,
      },
    )
  end

  def show_toast(type:, post: reply_post, into: topic)
    push_from_post(type: type, post: post, into: into)
    expect(page).to have_css(".jtech-popup-toast", wait: 10)
  end

  def dismiss_toast
    find("#post_1 .cooked").click
    expect(page).to have_no_css(".jtech-popup-toast")
  end

  def open_account_preference
    sign_in(recipient)
    visit("/u/#{recipient.username}/preferences/account")
    expect(page).to have_css(".jtech-desktop-popup-notifications", wait: 10)
  end

  def open_topic
    sign_in(recipient)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#post_1", wait: 10)
  end

  it "captures the account-page preference control (01–04)" do
    open_account_preference
    shot("01_settings_account_default_off")

    find(".jtech-desktop-popup-notifications .select-kit-header").click
    expect(page).to have_css(".select-kit-collection", wait: 5)
    shot("02_settings_dropdown_open")

    find(".select-kit-row", text: I18n.t("js.jtech_popup_notifications.preference.on")).click
    expect(page).to have_css(".jtech-desktop-popup-notifications")
    shot("03_settings_set_on")

    find(".jtech-desktop-popup-notifications .select-kit-header").click
    find(".select-kit-row", text: I18n.t("js.jtech_popup_notifications.preference.off")).click
    shot("04_settings_set_off")
  end

  it "captures the admin master switch (05)" do
    sign_in(admin)
    visit("/admin/site_settings/category/all_results?filter=popup_notifications")
    expect(page).to have_css(".setting", wait: 10)
    shot("05_settings_admin_master_switch")
  end

  it "hides the account control when the master switch is off (06)" do
    SiteSetting.popup_notifications_enabled = false
    sign_in(recipient)
    visit("/u/#{recipient.username}/preferences/account")
    expect(page).to have_css(".user-preferences", wait: 10)
    expect(page).to have_no_css(".jtech-desktop-popup-notifications")
    shot("06_settings_control_hidden_master_off")
  end

  it "captures a toast for each notification type (07–11)" do
    open_topic

    show_toast(type: :replied)
    shot("07_toast_reply")
    dismiss_toast

    show_toast(type: :mentioned)
    shot("08_toast_mention")
    dismiss_toast

    show_toast(type: :quoted)
    shot("09_toast_quote")
    dismiss_toast

    show_toast(type: :private_message)
    shot("10_toast_private_message")
    dismiss_toast

    show_toast(type: :liked)
    shot("11_toast_liked")
  end

  it "captures content-shape variety: long title, long message, icon fallback (12–14)" do
    open_topic

    # Long topic title → ellipsis on the bold title line.
    show_toast(type: :replied, post: long_topic_reply, into: long_topic)
    shot("12_toast_long_title")
    dismiss_toast

    # Long message → the preview line clamps to two lines.
    show_toast(type: :replied, post: long_reply)
    shot("13_toast_long_message")
    dismiss_toast

    # No source post → the avatar slot falls back to the bell icon, and the
    # preview comes straight from the notification data.
    push(
      type: :custom,
      data: {
        display_username: "system_sam",
        topic_title: "Scheduled maintenance tonight",
        excerpt: "The forum will be briefly unavailable around 2am for a database upgrade.",
        url: "/u/#{recipient.username}/notifications",
      },
    )
    expect(page).to have_css(".jtech-popup-toast .d-icon-bell", wait: 10)
    shot("14_toast_fallback_icon")
  end

  it "shows nothing extra when the preference is off (15)" do
    recipient.custom_fields[user_field] = false
    recipient.save_custom_fields(true)
    open_topic

    push_from_post(type: :replied, post: reply_post)
    # The core bell still works; the additive toast never appears.
    expect(page).to have_no_css(".jtech-popup-toast", wait: 5)
    shot("15_notification_off_no_popup")
  end
end
