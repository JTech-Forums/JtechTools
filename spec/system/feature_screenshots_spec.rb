# frozen_string_literal: true

require "rails_helper"

# Visual captures of each behavior added by the
# "Audience-aware whisper unread + merge mod-note bell + badge targeting"
# change set, so a reviewer can eyeball them from CI without spinning up a
# local Discourse. PNGs are written into `tmp/capybara/feature_screenshots/`
# and are picked up by the `feature-screenshots.yml` workflow's
# `actions/upload-artifact@v6` step (`if: always()` — uploaded regardless
# of pass/fail).
RSpec.describe "Feature screenshots", type: :system do
  fab!(:admin) { Fabricate(:admin, username: "screen_admin") }
  fab!(:moderator) { Fabricate(:moderator, username: "screen_mod") }
  fab!(:author, :user) { Fabricate(:user, username: "screen_author") }
  fab!(:audience_user, :user) { Fabricate(:user, username: "screen_audience") }
  fab!(:stranger, :user) { Fabricate(:user, username: "screen_stranger") }
  fab!(:badge_holder, :user) { Fabricate(:user, username: "screen_badge_holder") }
  fab!(:badge) { Fabricate(:badge, name: "ScreenshotBadge") }
  fab!(:category)

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:participants_field) { DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    Group.refresh_automatic_groups!
    SiteSetting.approve_unless_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

    BadgeGranter.grant(badge, badge_holder)

    FileUtils.mkdir_p("tmp/capybara/feature_screenshots")
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
      # Capture anyway rather than failing on a slow image.
    end
    page.save_screenshot("tmp/capybara/feature_screenshots/#{name}.png")
  end

  def topic_with_whisper(audience_ids: [audience_user.id])
    topic = Fabricate(:topic, category: category, title: "Audience-aware whisper demo")
    Fabricate(:post, topic: topic, user: author, raw: "OP body for the visual capture.")
    Fabricate(:post, topic: topic, user: author, raw: "Public reply visible to everyone.")
    whisper = Fabricate(:post, topic: topic, user: moderator, raw: "Mod-only whisper body.")
    whisper.custom_fields[targets_field] = audience_ids
    whisper.save_custom_fields(true)
    topic.custom_fields[participants_field] = audience_ids
    topic.save_custom_fields(true)
    # Mirror the on(:post_created) rollback so the visual matches what
    # production sees after a whisper is posted.
    non_whisper_max =
      Post
        .where(topic_id: topic.id, deleted_at: nil)
        .where.not(id: PostCustomField.where(name: targets_field).select(:post_id))
        .maximum(:post_number)
    Topic.where(id: topic.id).update_all(highest_post_number: non_whisper_max) if non_whisper_max
    topic.reload
  end

  it "1. captures the topic list with no unread bump for a non-audience viewer" do
    topic_with_whisper
    sign_in(stranger)
    visit("/latest")
    expect(page).to have_css(".topic-list", wait: 15)
    shot("01_non_audience_no_badge")
  end

  it "2. captures the topic list WITH the unread bump for an audience viewer" do
    topic_with_whisper(audience_ids: [audience_user.id])
    sign_in(audience_user)
    visit("/latest")
    expect(page).to have_css(".topic-list", wait: 15)
    shot("02_audience_sees_badge")
  end

  it "3. captures the standard bell with a mod-note notification (no separate header pip)" do
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: moderator.id,
      high_priority: true,
      data: {
        topic_title: "Heads up, staff",
        display_username: admin.username,
        mod_note: true,
        url: "/",
        message: "discourse_mod_categories.note_notification",
        title: "discourse_mod_categories.note_notification_title",
      }.to_json,
    )

    sign_in(moderator)
    visit("/")
    expect(page).to have_css(".d-header", wait: 15)
    shot("03_bell_header_no_separate_pip")

    begin
      find(".header-dropdown-toggle.current-user button", match: :first).click
    rescue StandardError
      nil
    end
    sleep 0.5
    shot("04_user_menu_with_mod_note_in_bell")
  end

  it "4. captures the whisper composer toolbar modal with the badge picker" do
    topic = Fabricate(:topic, category: category, title: "Whisper composer demo")
    Fabricate(:post, topic: topic, user: author, raw: "OP for whisper composer demo.")

    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".topic-post", wait: 15)

    find("#topic-footer-buttons .create", match: :first).click
    expect(page).to have_css(".d-editor-input", wait: 15)

    # The whisper toolbar button — clicking it as staff opens the target modal.
    find(
      ".d-editor-button-bar button.mod-whisper-target, " \
        ".d-editor-button-bar button[title='" \
        "#{I18n.t("js.discourse_mod_categories.whisper.toolbar_title")}']",
      match: :first,
    ).click

    expect(page).to have_css(".mod-whisper-target-modal", wait: 15)
    # The badge picker appears when at least one enabled badge exists; the
    # fab!(:badge) at the top of the spec ensures that.
    shot("05_whisper_modal_with_badge_picker")
  end

  it "5. captures the PM composer with the 'Add badge group' button" do
    sign_in(moderator)
    visit("/")
    expect(page).to have_css(".d-header", wait: 15)

    # Open a new PM via the URL fragment that opens the composer.
    visit("/new-message?username=#{audience_user.username}")
    expect(page).to have_css(".composer-fields", wait: 15)
    sleep 0.5
    shot("06_pm_composer_add_badge_group_button")
  end
end
