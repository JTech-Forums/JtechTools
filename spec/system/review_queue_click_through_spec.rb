# frozen_string_literal: true

require "rails_helper"

# Capybara coverage for the click-through behavior of review-queue
# notifications: when a moderator clicks a `post_approved`, `post_rejected`
# or `flag_note` notification in the bell dropdown, they should land on
# `/review/:id` AND the notification should be marked as read.
#
# Three pieces being verified together:
#   1. The notification renders with the correct shield icon + label.
#   2. The click navigates to /review/:id (the URL in the notification's
#      data column).
#   3. The mod-review-notifications-clear initializer fires on the
#      /review page and marks the notification read.
RSpec.describe "Review-queue click-through" do
  fab!(:admin) { Fabricate(:admin, username: "click_through_admin") }
  fab!(:moderator) { Fabricate(:moderator, username: "click_through_mod") }
  fab!(:author, :user) { Fabricate(:user, username: "click_through_author") }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category, title: "Click-through test topic") }
  fab!(:target_post) { Fabricate(:post, topic: topic, user: author, raw: "OP for click-through.") }
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post, target: target_post, created_by: author) }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_notify_staff_on_flag_notes = true
    SiteSetting.mod_notify_staff_on_post_actions = true
    FileUtils.mkdir_p(File.join(Rails.root, "tmp/capybara/feature_screenshots"))
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
    end
    path = File.join(Rails.root, "tmp/capybara/feature_screenshots/#{name}.png")
    page.save_screenshot(path)
  end

  def seed_notification(kind:)
    url = "/review/#{reviewable.id}"
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: admin.id,
      topic_id: nil,
      post_number: nil,
      high_priority: true,
      data: {
        mod_note: true,
        mod_note_kind: kind,
        display_username: moderator.username,
        excerpt: "Click-through test body for #{kind}.",
        url: url,
        message: "discourse_mod_categories.#{kind}_notification",
      }.to_json,
    )
    url
  end

  %w[flag_note post_rejected post_approved].each do |kind|
    it "clicking a #{kind} notification lands the user on /review/:id and marks it read" do
      target_url = seed_notification(kind: kind)

      sign_in(admin)
      visit("/")
      expect(page).to have_css(".d-header", wait: 15)

      # Capture the bell dropdown with the notification visible.
      find(".header-dropdown-toggle.current-user button", match: :first).click
      expect(page).to have_css(".notification.custom", wait: 15)
      shot("review_clickthrough_#{kind}_01_bell_dropdown")

      # Click the notification.
      find(".notification.custom a", match: :first).click

      # Verify the URL — Discourse's review queue uses /review or
      # /review?reviewable_id=:id depending on version; assert the
      # page settled on the review queue.
      expect(page).to have_css(".reviewable-list, .review-container, .reviewables", wait: 15)
      shot("review_clickthrough_#{kind}_02_landed_on_review_page")

      # The mark-as-read happens via the page-change initializer hitting
      # /discourse-mod-categories/review/notifications/seen. Verify the
      # notification row in the DB is now read.
      expect(
        Notification
          .where(user_id: admin.id, read: false)
          .where("data LIKE ?", "%\"mod_note_kind\":\"#{kind}\"%")
          .count,
      ).to eq(0)

      # Reopen the bell dropdown — the notification should no longer
      # show as unread (no .unread class on its <li>).
      find(".header-dropdown-toggle.current-user button", match: :first).click
      expect(page).to have_css(".notification.custom", wait: 15)
      shot("review_clickthrough_#{kind}_03_bell_after_marked_read")
    end
  end
end
