# frozen_string_literal: true

require "rails_helper"

# Visual + behaviour coverage of the second `?type=` filter dropdown on
# /u/{username}/notifications added by the plugin. Two regressions
# user-reported on the live forum:
#
#   1. Picking a type from the dropdown updated the URL but did NOT
#      refilter the list — the route was treating a same-path query-
#      param-only transition as a no-op since `type` isn't declared as
#      a controller queryParam.
#   2. A direct URL of `/u/{username}/notifications?type=Boost` (note
#      the capital) wasn't filtering either — the server controller
#      matched against `Notification.types.key?(requested_type.to_sym)`
#      which is case-sensitive against lowercase snake_case keys.
#
# The spec exercises both flows with a real ember boot + browser, and
# saves screenshots into `tmp/capybara/feature_screenshots/` for
# eyeballing in the CI artifact.
RSpec.describe "Notifications type filter" do
  fab!(:viewer) { Fabricate(:user, username: "notif_filter_viewer") }
  fab!(:other_user) { Fabricate(:user, username: "notif_filter_other") }

  let(:liked_notification) do
    Fabricate(
      :notification,
      user: viewer,
      notification_type: Notification.types[:liked],
      data: { display_username: other_user.username }.to_json,
    )
  end

  let(:replied_notification) do
    Fabricate(
      :notification,
      user: viewer,
      notification_type: Notification.types[:replied],
      data: { display_username: other_user.username }.to_json,
    )
  end

  before do
    SiteSetting.mod_categories_enabled = true
    FileUtils.mkdir_p(File.join(Rails.root, "tmp/capybara/feature_screenshots"))

    liked_notification
    replied_notification

    sign_in(viewer)
  end

  def shot(name)
    path = File.join(Rails.root, "tmp/capybara/feature_screenshots/notif_filter_#{name}.png")
    page.save_screenshot(path)
  end

  it "filters live when a type is picked from the dropdown (no full reload)" do
    visit("/u/#{viewer.username}/notifications")
    expect(page).to have_css(".user-notifications-filter", wait: 15)
    expect(page).to have_css(".notifications-type-filter", wait: 10)

    # Both notifications visible before any filtering.
    expect(page).to have_css(".notification.liked")
    expect(page).to have_css(".notification.replied")
    shot("before_pick")

    # Open the plugin's second dropdown and pick "Liked".
    find(".notifications-type-filter .select-kit-header").click
    expect(page).to have_css(
      ".notifications-type-filter .select-kit-row[data-value='liked']",
      wait: 5,
    )
    find(".notifications-type-filter .select-kit-row[data-value='liked']").click

    # The pre-fix bug: URL updated but the visible list stayed at both
    # rows because the route didn't refresh. Post-fix: the route refreshes
    # and the list collapses to the picked type.
    expect(page).to have_current_path(
      "/u/#{viewer.username}/notifications?type=liked",
      ignore_query: false,
      wait: 5,
    )
    expect(page).to have_css(".notification.liked")
    expect(page).to have_no_css(".notification.replied", wait: 5)
    shot("after_pick_liked")
  end

  it "filters live when the URL is loaded directly with a known type" do
    visit("/u/#{viewer.username}/notifications?type=replied")
    expect(page).to have_css(".user-notifications-filter", wait: 15)
    expect(page).to have_css(".notification.replied")
    expect(page).to have_no_css(".notification.liked", wait: 5)
    shot("direct_url_replied")
  end

  it "matches the type case-insensitively (?type=Liked works like ?type=liked)" do
    # Pre-fix: the server's `Notification.types.key?(:Liked)` was false, so
    # the filter was dropped and the full list rendered. Post-fix: a casefold
    # match plucks the canonical key, then the standard filter_by_types path
    # narrows the result.
    visit("/u/#{viewer.username}/notifications?type=Liked")
    expect(page).to have_css(".user-notifications-filter", wait: 15)
    expect(page).to have_css(".notification.liked")
    expect(page).to have_no_css(".notification.replied", wait: 5)
    shot("direct_url_Liked_capitalized")
  end

  it "returns to the unfiltered list when 'All' is selected" do
    visit("/u/#{viewer.username}/notifications?type=liked")
    expect(page).to have_css(".user-notifications-filter", wait: 15)
    expect(page).to have_css(".notification.liked")

    find(".notifications-type-filter .select-kit-header").click
    find(".notifications-type-filter .select-kit-row[data-value='all']").click

    expect(page).to have_current_path("/u/#{viewer.username}/notifications", wait: 5)
    expect(page).to have_css(".notification.liked")
    expect(page).to have_css(".notification.replied")
    shot("after_back_to_all")
  end
end
