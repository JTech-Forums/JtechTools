# frozen_string_literal: true

require "rails_helper"

# End-to-end coverage for the per-topic prompt checklist: staff add the
# checklist to a topic via the wrench-menu "Prompt Checklist" entry,
# another user replies and is prompted, accepts, posts, and is not
# prompted again until staff bump the version. Screenshots are written
# to tmp/capybara/ and published as the CI artifact.
RSpec.describe "Per-topic prompt checklist" do
  fab!(:moderator)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:tl0_user) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category, title: "Gated reply thread") }
  fab!(:first_post) { Fabricate(:post, topic: topic, raw: "The original post in this thread.") }

  TOPIC_FIELD = DiscourseModCategories::TOPIC_PROMPT_CHECKLIST_FIELD
  USER_FIELD = DiscourseModCategories::USER_TOPIC_CHECKLIST_FIELD

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    SiteSetting.approve_unless_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
    SiteSetting.approve_post_count = 0
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
    end
    page.save_screenshot("#{name}.png")
  end

  def set_topic_checklist(version:, items:, button_label: "I agree, post my reply")
    topic.custom_fields[TOPIC_FIELD] = {
      "version" => version,
      "items" => items,
      "button_label" => button_label,
      "updated_at" => Time.zone.now.iso8601,
    }
    topic.save_custom_fields(true)
  end

  def open_admin_menu
    find(".toggle-admin-menu", match: :first).click
  end

  def open_reply
    find("#topic-footer-buttons .create", match: :first).click
    find(".d-editor-input").fill_in(with: "Here is my reply on the forum.")
    find(".save-or-cancel .create").click
  end

  it "lets staff open the editor, add items, save, and re-prompt a user" do
    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#topic-title", wait: 10)
    shot("171_topic_page_moderator")

    open_admin_menu
    expect(page).to have_css(".mod-topic-prompt-checklist-button", wait: 10)
    shot("172_topic_admin_menu_with_prompt_checklist")

    find(".mod-topic-prompt-checklist-button").click
    expect(page).to have_css(".mod-topic-prompt-checklist-modal", wait: 10)
    expect(page).to have_css(".mod-topic-prompt-checklist-inactive", wait: 10)
    shot("173_topic_prompt_checklist_modal_empty")

    find(".mod-topic-prompt-checklist-add").click
    all(".mod-topic-prompt-checklist-modal .mod-checklist-row-label").last.fill_in(
      with: "Confirm this is a real reply, not spam",
    )
    find(".mod-topic-prompt-checklist-add").click
    all(".mod-topic-prompt-checklist-modal .mod-checklist-row-label").last.fill_in(
      with: "I read the topic guidelines",
    )
    find(".mod-topic-prompt-checklist-button-label").fill_in(with: "I agree, post my reply")
    shot("174_topic_prompt_checklist_modal_filled")

    find(".mod-topic-prompt-checklist-save").click
    expect(page).to have_css(".fk-d-toast", wait: 10)
    shot("175_topic_prompt_checklist_saved")

    stored = topic.reload.custom_fields[TOPIC_FIELD]
    expect(stored["version"]).to eq(1)
    expect(stored["items"].size).to eq(2)
  end

  it "prompts another user replying to the topic, then leaves them alone after accept" do
    set_topic_checklist(
      version: 1,
      items: [
        { "label" => "Confirm this is a real reply, not spam", "url" => "" },
        { "label" => "I read the topic guidelines", "url" => "" },
      ],
    )

    sign_in(user)
    visit("/t/#{topic.slug}/#{topic.id}")
    open_reply

    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    shot("176_topic_prompt_checklist_user_prompted")

    all(".mod-checklist-checkbox").each(&:click)
    shot("177_topic_prompt_checklist_user_all_checked")

    find(".mod-checklist-confirm").click
    expect(page).to have_css(".topic-post", minimum: 2, wait: 10)
    shot("178_topic_prompt_checklist_user_reply_posted")

    # Reload-free second reply: not prompted again.
    open_reply
    expect(page).to have_css(".topic-post", minimum: 3, wait: 10)
    expect(page).to have_no_css(".mod-first-post-checklist-modal")
    shot("179_topic_prompt_checklist_user_second_reply_no_prompt")

    map = user.reload.custom_fields[USER_FIELD]
    expect(map[topic.id.to_s]).to eq(1)
  end

  it "re-prompts the same user after a version bump" do
    set_topic_checklist(version: 1, items: [{ "label" => "Rule one", "url" => "" }])
    user.upsert_custom_fields(USER_FIELD => { topic.id.to_s => 1 })

    # Staff bump.
    set_topic_checklist(version: 2, items: [{ "label" => "Updated rule one", "url" => "" }])

    sign_in(user)
    visit("/t/#{topic.slug}/#{topic.id}")
    open_reply

    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    shot("180_topic_prompt_checklist_user_reprompt_after_bump")
  end

  it "shows the statement-mode prompt with a single accept button" do
    topic.custom_fields[TOPIC_FIELD] = {
      "version" => 1,
      "mode" => "statement",
      "statement" => "Please confirm you have read the topic guidelines.",
      "items" => [],
      "frequency" => "once",
      "max_tl" => 4,
      "button_label" => "I confirm",
      "updated_at" => Time.zone.now.iso8601,
    }
    topic.save_custom_fields(true)

    sign_in(user)
    visit("/t/#{topic.slug}/#{topic.id}")
    open_reply

    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    expect(page).to have_css(".mod-checklist-statement", wait: 10)
    expect(page).to have_no_css(".mod-checklist-checkbox")
    # The confirm button is enabled immediately since there is nothing
    # to tick.
    expect(page).to have_css(".mod-checklist-confirm:not([disabled])")
    shot("181_topic_prompt_statement_mode_user_prompted")

    find(".mod-checklist-confirm").click
    expect(page).to have_css(".topic-post", minimum: 2, wait: 10)
    shot("182_topic_prompt_statement_mode_posted")
  end

  it "re-prompts on every reply when frequency is every_reply" do
    topic.custom_fields[TOPIC_FIELD] = {
      "version" => 1,
      "mode" => "checklist",
      "items" => [{ "label" => "Confirm on every reply", "url" => "" }],
      "frequency" => "every_reply",
      "max_tl" => 4,
      "button_label" => "I confirm",
      "updated_at" => Time.zone.now.iso8601,
    }
    topic.save_custom_fields(true)

    sign_in(user)
    visit("/t/#{topic.slug}/#{topic.id}")
    open_reply

    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    all(".mod-checklist-checkbox").each(&:click)
    find(".mod-checklist-confirm").click
    expect(page).to have_css(".topic-post", minimum: 2, wait: 10)
    shot("183_topic_prompt_every_reply_first_reply")

    # Second reply: the checklist must fire again — frequency=every_reply
    # disregards the user's previously-recorded acceptance.
    open_reply
    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    shot("184_topic_prompt_every_reply_second_reply_reprompted")
  end

  it "does not prompt a user above the max_tl cap" do
    topic.custom_fields[TOPIC_FIELD] = {
      "version" => 1,
      "mode" => "checklist",
      "items" => [{ "label" => "Only TL0/TL1 are prompted", "url" => "" }],
      "frequency" => "once",
      "max_tl" => 1,
      "button_label" => "Confirm",
      "updated_at" => Time.zone.now.iso8601,
    }
    topic.save_custom_fields(true)

    # `user` is TL2 — above the TL1 cap, so they should NOT be prompted.
    sign_in(user)
    visit("/t/#{topic.slug}/#{topic.id}")
    open_reply

    expect(page).to have_css(".topic-post", minimum: 2, wait: 10)
    expect(page).to have_no_css(".mod-first-post-checklist-modal")
    shot("185_topic_prompt_max_tl_cap_skipped_for_higher_tl")
  end

  it "lets staff switch the editor to Statement mode, save, and prompts a user" do
    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#topic-title", wait: 10)

    open_admin_menu
    expect(page).to have_css(".mod-topic-prompt-checklist-button", wait: 10)
    find(".mod-topic-prompt-checklist-button").click
    expect(page).to have_css(".mod-topic-prompt-checklist-modal", wait: 10)

    mode = PageObjects::Components::SelectKit.new(".mod-topic-prompt-checklist-mode")
    mode.expand
    mode.select_row_by_value("statement")
    expect(page).to have_css(".mod-topic-prompt-checklist-statement", wait: 10)
    find(".mod-topic-prompt-checklist-statement").fill_in(
      with: "Please read the rules before posting.",
    )
    find(".mod-topic-prompt-checklist-button-label").fill_in(with: "I agree")
    find(".mod-topic-prompt-checklist-save").click
    expect(page).to have_css(".fk-d-toast", wait: 10)
    shot("187_topic_prompt_statement_editor_saved")

    stored = topic.reload.custom_fields[TOPIC_FIELD]
    expect(stored["mode"]).to eq("statement")
    expect(stored["statement"]).to eq("Please read the rules before posting.")

    # A regular user replying is now prompted with the statement modal,
    # with the accept button enabled immediately and no checkboxes.
    sign_in(user)
    visit("/t/#{topic.slug}/#{topic.id}")
    open_reply

    expect(page).to have_css(".mod-first-post-checklist-modal", wait: 10)
    expect(page).to have_css(".mod-checklist-statement", wait: 10)
    expect(page).to have_no_css(".mod-checklist-checkbox")
    expect(page).to have_css(".mod-checklist-confirm:not([disabled])")
    shot("188_topic_prompt_statement_editor_then_user_prompted")

    find(".mod-checklist-confirm").click
    expect(page).to have_css(".topic-post", minimum: 2, wait: 10)
    shot("189_topic_prompt_statement_editor_then_user_posted")
  end

  it "no longer shows the before-reply prompt field in the Moderator Actions modal" do
    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#topic-title", wait: 10)

    find(".toggle-admin-menu", match: :first).click
    expect(page).to have_css(".mod-topic-messages-button", wait: 10)
    find(".mod-topic-messages-button").click
    expect(page).to have_css(".mod-topic-messages-modal", wait: 10)

    # The legacy section is gone — moderators now configure the prompt
    # exclusively through the Prompt Checklist entry.
    expect(page).to have_no_css(".mod-reply-input")
    expect(page).to have_no_css(".mod-reply-audience-input")
    shot("186_moderator_actions_modal_no_reply_prompt")
  end
end
