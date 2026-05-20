# frozen_string_literal: true

require "rails_helper"

# End-to-end coverage for the header-level moderator-notes indicators.
#
# Two staff-only signals:
#   1. A small badge overlaid on the current-user avatar in the header
#      carrying the unread count, visible whenever the user menu is
#      *closed*.
#   2. A `(N)` prefix on `document.title`, mirroring the bell's behaviour.
#
# Both reset to "nothing" once the staff member opens the shield tab —
# `POST /notes-feed/seen` clears `mod_notes_seen_at`, and the panel
# component zeroes `currentUser.mod_note_unread_count` locally.
RSpec.describe "Moderator-note header indicators" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category, title: "Share your app build here") }
  fab!(:first_post) { Fabricate(:post, topic: topic, raw: "Drop your app uploads in this thread.") }

  before do
    SiteSetting.mod_categories_enabled = true
    topic.custom_fields["mod_topic_private_note"] = "Please review this thread."
    topic.custom_fields["mod_topic_private_note_user_id"] = admin.id
    topic.custom_fields["mod_topic_private_note_activity_at"] = Time.zone.now.iso8601
    topic.save_custom_fields(true)
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
      # Capture anyway rather than failing the spec over a slow image.
    end
    page.save_screenshot("#{name}.png")
  end

  it "renders the avatar pip with the unread count for a staff user" do
    sign_in(moderator)

    visit("/")
    expect(page).to have_css(".mod-note-avatar-pip.visible", wait: 10)
    count =
      page.evaluate_script("document.querySelector('.mod-note-avatar-pip')?.dataset.count || ''")
    expect(count).to match(/\d/)
    shot("190_mod_note_header_pip_visible")
  end

  it "prefixes the document title with (N) when there are unread notes" do
    sign_in(moderator)

    visit("/")
    expect(page).to have_css(".mod-note-avatar-pip.visible", wait: 10)

    # Discourse's `document-title` service rewrites `<title>` on every
    # route transition; our MutationObserver re-applies the `(N)` prefix
    # after each rewrite. Visit a topic so a stable, non-empty bare
    # title is in flight, then poll for the prefix.
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#topic-title", wait: 10)

    title =
      Timeout.timeout(15) do
        loop do
          t = page.evaluate_script("document.title")
          break t if t =~ /^\(\d+\)\s/
          sleep 0.2
        end
      end

    expect(title).to match(/^\(\d+\)\s/)
    shot("191_mod_note_browser_title_prefix")
  end

  it "clears the pip and the title prefix after the shield tab is opened" do
    sign_in(moderator)

    visit("/")
    expect(page).to have_css(".mod-note-avatar-pip.visible", wait: 10)

    # Opening the shield tab marks the feed as seen and resets the count.
    find(".header-dropdown-toggle.current-user").click
    expect(page).to have_css("#user-menu-button-discourse-mod-notes", wait: 10)
    find("#user-menu-button-discourse-mod-notes").click
    expect(page).to have_css(".mod-notes-panel", wait: 10)

    # Wait for the panel's `notes-feed/seen` POST to complete so the
    # currentUser count is actually zeroed before we check the badge.
    # The badge renders its number via a CSS `::before` pseudo, so we
    # read `dataset.count` instead of textContent.
    Timeout.timeout(10) do
      loop do
        count =
          page
            .evaluate_script("document.querySelector('.mod-note-avatar-pip')?.dataset.count || ''")
            .to_s
            .strip
        break if count.empty? || count == "0"
        sleep 0.2
      end
    end

    # Close the user menu so we can verify the badge is no longer visible.
    find("body").send_keys(:escape)
    expect(page).to have_no_css(".mod-note-avatar-pip.visible", wait: 10)

    # Title prefix is back to the bare title.
    expect(page.evaluate_script("document.title")).not_to match(/^\(\d+\)\s/)
    shot("192_mod_note_header_indicators_cleared_after_seen")
  end

  it "is never rendered for a regular user" do
    sign_in(user)

    visit("/")
    expect(page).to have_css("#site-logo, .d-header", wait: 10)
    expect(page).to have_no_css(".mod-note-avatar-pip.visible")
  end
end
