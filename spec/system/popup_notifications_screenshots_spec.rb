# frozen_string_literal: true

require "rails_helper"

# Screenshot gallery for the desktop pop-up notification feature — 18 shots
# across the two surfaces the user interacts with:
#
#   * the account page where the preference is set (shots 01–04), plus the
#     admin master switch (05) and the control hidden when the master is off
#     (06); and
#   * the page where the notification arrives — the toast itself, across
#     notification types (07–11), content shapes (12–14), the off state (15),
#     and the plugin's own custom types: whisper, flag, pending (16–18).
#
# Each toast shot loads the page fresh and publishes exactly ONE crafted
# notification on the user's `/notification/:id` MessageBus channel (the same
# channel core uses). One publish per fresh page is the reliable path in the
# parallel system-test runner. The real end-to-end delivery is covered by
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
  # Mutable memoized counter (avoids an instance variable) so every crafted
  # notification gets a fresh id.
  let(:id_seq) { [500_000] }

  # Gallery spec: generates screenshots in the Feature Screenshots workflow
  # (which sets this env). Skipped in the main parallel system_tests run so it
  # does not weigh that job down — core behavior is covered by
  # popup_notifications_spec.rb.
  before { skip("screenshot-gallery only") unless ENV["JTECH_SCREENSHOT_GALLERY"] }

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

  def set_pref(value)
    recipient.custom_fields[user_field] = value
    recipient.save_custom_fields(true)
  end

  # Publish a crafted notification on the recipient's channel.
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

  # A reply-shaped notification enriched from a real post (avatar + excerpt),
  # varying only the type so each screenshot is a distinct kind.
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

  def visit_topic(into = topic)
    visit("/t/#{into.slug}/#{into.id}")
    expect(page).to have_css("#post_1", wait: 10)
  end

  # After a warm page load `#post_1` can appear before the browser's
  # MessageBus poll re-establishes its subscription, so a single publish can
  # land before the client is listening and be missed. Re-publish (a fresh id
  # each time) until the toast — or a specific icon within it — appears.
  def wait_for_toast(selector = ".jtech-popup-toast")
    8.times do
      yield
      return if page.has_css?(selector, wait: 1.5)
    end
    expect(page).to have_css(selector, wait: 5)
  end

  # One shot = one fresh page + a publish (retried until it lands).
  def enriched_toast_shot(name, type:, post: reply_post, into: topic)
    visit_topic(into)
    wait_for_toast { push_from_post(type: type, post: post, into: into) }
    shot(name)
  end

  def open_account_preference
    sign_in(recipient)
    visit("/u/#{recipient.username}/preferences/account")
    expect(page).to have_css(".jtech-desktop-popup-notifications", wait: 10)
  end

  it "captures the account-page preference control (01–04)" do
    open_account_preference
    shot("01_settings_account_default_off")

    find(".jtech-desktop-popup-notifications .select-kit-header").click
    expect(page).to have_css(".select-kit-collection", wait: 5)
    shot("02_settings_dropdown_open")

    find(".select-kit-row", text: "On").click
    expect(page).to have_css(".jtech-desktop-popup-notifications")
    shot("03_settings_set_on")

    find(".jtech-desktop-popup-notifications .select-kit-header").click
    find(".select-kit-row", text: "Off").click
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
    sign_in(recipient)
    enriched_toast_shot("07_toast_reply", type: :replied)
    enriched_toast_shot("08_toast_mention", type: :mentioned)
    enriched_toast_shot("09_toast_quote", type: :quoted)
    enriched_toast_shot("10_toast_private_message", type: :private_message)
    enriched_toast_shot("11_toast_liked", type: :liked)
  end

  it "captures content-shape variety: long title, long message, icon fallback (12–14)" do
    sign_in(recipient)

    # Long topic title → ellipsis on the bold title line.
    enriched_toast_shot(
      "12_toast_long_title",
      type: :replied,
      post: long_topic_reply,
      into: long_topic,
    )

    # Long message → the preview line clamps to two lines.
    enriched_toast_shot("13_toast_long_message", type: :replied, post: long_reply)

    # No source post → the type icon renders on its own, preview from data.
    visit_topic
    wait_for_toast(".jtech-popup-toast .d-icon-bell") do
      push(
        type: :custom,
        data: {
          display_username: "system_sam",
          topic_title: "Scheduled maintenance tonight",
          excerpt: "The forum will be briefly unavailable around 2am for a database upgrade.",
          url: "/u/#{recipient.username}/notifications",
        },
      )
    end
    shot("14_toast_fallback_icon")
  end

  it "shows nothing extra when the preference is off (15)" do
    set_pref(false)
    sign_in(recipient)
    visit_topic

    push_from_post(type: :replied, post: reply_post)
    expect(page).to have_no_css(".jtech-popup-toast", wait: 5)
    shot("15_notification_off_no_popup")
  end

  it "captures the plugin's custom types: whisper, flag, pending (16–18)" do
    sign_in(recipient)

    # Moderator whisper — enriched from a real post, with the eye badge.
    visit_topic
    wait_for_toast(".jtech-popup-toast .d-icon-eye") do
      push(
        type: :custom,
        topic_id: topic.id,
        post_number: reply_post.post_number,
        slug: topic.slug,
        fancy_title: topic.fancy_title,
        data: {
          mod_whisper: true,
          display_username: author.username,
          topic_title: topic.title,
          original_post_id: reply_post.id,
        },
      )
    end
    shot("16_toast_whisper")

    # Flag note — no source post, so the flag type icon renders on its own.
    visit_topic
    wait_for_toast(".jtech-popup-toast .d-icon-flag") do
      push(
        type: :custom,
        data: {
          mod_note: true,
          mod_note_kind: "flag_note",
          display_username: "mod_mia",
          excerpt: "Flagged as spam — please review.",
          url: "/review",
        },
      )
    end
    shot("17_toast_flag")

    # Queued / pending post approved by staff.
    visit_topic
    wait_for_toast(".jtech-popup-toast .d-icon-check") do
      push(
        type: :custom,
        data: {
          mod_note: true,
          mod_note_kind: "post_approved",
          display_username: "mod_mia",
          topic_title: topic.title,
          excerpt: "Approved a post that was awaiting review.",
          url: "/review",
        },
      )
    end
    shot("18_toast_pending_approved")
  end
end
