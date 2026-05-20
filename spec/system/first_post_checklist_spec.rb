# frozen_string_literal: true

require "rails_helper"

# End-to-end coverage for the first-post checklist: the moderator config
# modal (opened from the sidebar), and the modal a new user must complete
# before their first post. Screenshots are written to tmp/capybara/ for
# the CI artifact.
RSpec.describe "First-post checklist", type: :system do
  fab!(:moderator)
  fab!(:user) do
    Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
  end
  fab!(:tl0_user) do
    Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true)
  end
  fab!(:category)
  fab!(:topic) do
    Fabricate(:topic, category: category, title: "An existing app thread")
  end
  fab!(:first_post) do
    Fabricate(:post, topic: topic, raw: "The original post in this thread.")
  end

  NS = DiscourseModCategories::CHECKLIST_STORE_NAMESPACE
  KEY = DiscourseModCategories::CHECKLIST_STORE_KEY
  LOG_KEY = DiscourseModCategories::CHECKLIST_LOG_KEY
  VERSION_FIELD = DiscourseModCategories::USER_CHECKLIST_VERSION_FIELD

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    # The spec fills the composer instantly; without this a TL0 user's
    # first post is held by the fast-typer review-queue check.
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    SiteSetting.approve_post_count = 0
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        until page.evaluate_script(
                "Array.from(document.images).every((i) => i.complete)",
              )
          sleep 0.1
        end
      end
    rescue Timeout::Error
      # Capture anyway rather than failing the spec over a slow image.
    end
    page.save_screenshot("#{name}.png")
  end

  def set_checklist(version:, max_tl: 2, button_label: "I agree, post")
    PluginStore.set(
      NS,
      KEY,
      {
        "version" => version,
        "max_tl" => max_tl,
        "button_label" => button_label,
        "updated_at" => Time.zone.now.iso8601,
        "items" => [
          {
            "label" => "I read the community guidelines",
            "url" => "https://example.com/guidelines",
          },
          {
            "label" => "This is an app upload, not an off-topic question",
            "url" => "",
          },
        ],
      },
    )
  end

  def open_checklist_modal
    visit("/")
    find("[data-list-item-name='mod-checklist']", wait: 10).click
    expect(page).to have_css(".mod-checklist-modal", wait: 10)
  end

  def open_reply
    find("#topic-footer-buttons .create", match: :first).click
    find(".d-editor-input").fill_in(with: "Here is my reply on the forum.")
    find(".save-or-cancel .create").click
  end

  it "lets a moderator configure the checklist from the sidebar modal" do
    sign_in(moderator)

    open_checklist_modal
    expect(page).to have_css(".mod-checklist-inactive")
    shot("51_checklist_editor_empty")

    find(".mod-checklist-add").click
    all(".mod-checklist-row-label").last.fill_in(
      with: "I read the community guidelines",
    )
    all(".mod-checklist-row-url").last.fill_in(
      with: "https://example.com/guidelines",
    )
    find(".mod-checklist-add").click
    all(".mod-checklist-row-label").last.fill_in(
      with: "This is an app upload, not an off-topic question",
    )
    audience = PageObjects::Components::SelectKit.new(".mod-checklist-audience")
    audience.expand
    audience.select_row_by_value("0")
    find(".mod-checklist-button-label").fill_in(with: "I agree, post my topic")
    shot("52_checklist_editor_filled")

    find(".mod-checklist-save").click
    expect(page).to have_css(".mod-checklist-saved", wait: 10)
    # The saved items round-trip back into the editor.
    expect(page).to have_css(".mod-checklist-row", count: 2)
    shot("53_checklist_editor_saved")
  end

  it "lets a moderator reorder checklist rows and persists the new order" do
    set_checklist(version: 1, max_tl: 2)
    sign_in(moderator)

    open_checklist_modal
    expect(page).to have_css(".mod-checklist-row", count: 2)
    # The up button on the first row and the down button on the last
    # row are disabled.
    expect(all(".mod-checklist-move-up").first).to be_disabled
    expect(all(".mod-checklist-move-down").last).to be_disabled

    # Move the second row above the first.
    all(".mod-checklist-move-up").last.click
    expect(all(".mod-checklist-row-label").first.value).to eq(
      "This is an app upload, not an off-topic question",
    )
    shot("75_checklist_rows_reordered")

    find(".mod-checklist-save").click
    expect(page).to have_css(".mod-checklist-saved", wait: 10)

    # The new order round-trips back from the server.
    stored = PluginStore.get(NS, KEY)
    expect(stored["items"].map { |i| i["label"] }).to eq(
      [
        "This is an app upload, not an off-topic question",
        "I read the community guidelines",
      ],
    )
  end

  it "requires a TL0 user to accept, then leaves their later posts alone" do
    set_checklist(version: 1, max_tl: 0, button_label: "I agree, post my reply")

    sign_in(tl0_user)
    visit(topic.url)
    open_reply

    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    shot("54_tl0_checklist_modal")

    all(".mod-checklist-checkbox").each(&:click)
    shot("55_tl0_modal_all_checked")

    find(".mod-checklist-confirm").click
    expect(page).to have_css(".topic-post", minimum: 2, wait: 10)
    shot("56_tl0_reply_posted_after_accept")

    open_reply
    expect(page).to have_css(".topic-post", minimum: 3, wait: 10)
    expect(page).to have_no_css(".mod-first-post-checklist-modal")
    shot("57_tl0_second_post_no_prompt")
  end

  it "shows the modal to a TL1 user under a TL0-TL2 checklist" do
    set_checklist(version: 1, max_tl: 2)

    sign_in(user)
    visit(topic.url)
    open_reply

    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    shot("58_tl1_checklist_modal")
  end

  it "re-prompts a user after the checklist version is bumped" do
    # The user accepted version 1; staff then publish version 2.
    set_checklist(version: 1, max_tl: 2)
    user.upsert_custom_fields(VERSION_FIELD => 1)
    set_checklist(version: 2, max_tl: 2)

    sign_in(moderator)
    open_checklist_modal
    expect(page).to have_css(".mod-checklist-version", text: "2")
    shot("59_checklist_version_bumped")

    sign_in(user)
    visit(topic.url)
    open_reply
    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    shot("60_reprompt_after_version_bump")
  end

  it "re-prompts mid-session after a version bump without a hard refresh" do
    # The TL1 user accepts version 1 in this browser session.
    set_checklist(version: 1, max_tl: 2)

    sign_in(user)
    visit(topic.url)
    open_reply

    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    # The "Last updated" line is shown on the accept modal.
    expect(page).to have_css(".mod-checklist-updated-at")
    shot("102_reprompt_session_first_accept")

    all(".mod-checklist-checkbox").each(&:click)
    find(".mod-checklist-confirm").click
    expect(page).to have_css(".topic-post", minimum: 2, wait: 10)

    # Staff bump the checklist to version 2 while the SAME browser session
    # stays open — no page reload happens after this point.
    set_checklist(version: 2, max_tl: 2)

    # SPA navigation only: click the header home logo (an Ember route
    # transition, not a document load) and back to the topic via its list
    # link. Capybara `visit` is deliberately NOT used here — a full reload
    # would re-bootstrap the current-user payload and mask the bug.
    find(".d-header .home-logo a, .d-header #site-logo, .d-header .title a",
         match: :first).click
    expect(page).to have_css(".topic-list-item", wait: 10)
    find(".topic-list-item a.title", match: :first).click
    expect(page).to have_css("#topic-footer-buttons", wait: 10)

    # Posting again re-prompts the user because the composer gate re-fetches
    # the owed checklist from the server — the stale bootstrapped value is
    # not trusted.
    open_reply
    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    expect(page).to have_css(".mod-checklist-updated-at")
    shot("103_reprompt_session_after_bump")
  end

  it "shows the acceptance audit log in the config modal" do
    set_checklist(version: 2, max_tl: 2)
    PluginStore.set(
      NS,
      LOG_KEY,
      [
        { "user_id" => tl0_user.id, "version" => 1, "at" => 2.days.ago.iso8601 },
        { "user_id" => user.id, "version" => 1, "at" => 1.day.ago.iso8601 },
        { "user_id" => tl0_user.id, "version" => 2, "at" => 1.hour.ago.iso8601 },
      ],
    )

    sign_in(moderator)
    open_checklist_modal
    expect(page).to have_css(".mod-checklist-log-table", wait: 10)
    expect(page).to have_css(".mod-checklist-log-table tbody tr", count: 3)
    shot("61_checklist_acceptance_log")
  end

  it "lets staff require a logged user to re-accept" do
    set_checklist(version: 1, max_tl: 2)
    user.upsert_custom_fields(VERSION_FIELD => 1)
    PluginStore.set(
      NS,
      LOG_KEY,
      [{ "user_id" => user.id, "version" => 1, "at" => 1.hour.ago.iso8601 }],
    )

    sign_in(moderator)
    open_checklist_modal
    expect(page).to have_css(".mod-checklist-log-table tbody tr", count: 1)
    shot("97_checklist_log_before_reaccept")

    find(".mod-checklist-require-reaccept").click
    expect(page).to have_css(".fk-d-toast", wait: 10)
    shot("98_checklist_require_reaccept")

    expect(user.reload.custom_fields[VERSION_FIELD]).to eq(0)
  end

  it "lets staff create a targeted checklist for a user who is then prompted" do
    sign_in(moderator)
    open_checklist_modal

    find(".mod-checklist-targeted-add").click
    find(".mod-checklist-targeted-name").fill_in(with: "App uploaders")

    picker = PageObjects::Components::SelectKit.new(".mod-checklist-targeted-users")
    picker.expand
    picker.search(user.username)
    picker.select_row_by_value(user.username)
    picker.collapse

    find(".mod-checklist-targeted-add-item").click
    all(".mod-checklist-targeted-item .mod-checklist-row-label").last.fill_in(
      with: "I read the app upload rules",
    )
    shot("99_targeted_checklist_filled")

    find(".mod-checklist-targeted-save").click
    expect(page).to have_css(".fk-d-toast", wait: 10)
    expect(page).to have_css(".mod-checklist-version", wait: 10)
    shot("100_targeted_checklist_saved")

    stored = DiscourseModCategories.targeted_checklists
    expect(stored.size).to eq(1)
    expect(stored.first["user_ids"]).to eq([user.id])

    # The targeted user is now prompted with this checklist on posting.
    sign_in(user)
    visit(topic.url)
    open_reply
    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    expect(page).to have_css(
      ".mod-checklist-text",
      text: "I read the app upload rules",
    )
    shot("101_targeted_checklist_prompt")
  end
end
