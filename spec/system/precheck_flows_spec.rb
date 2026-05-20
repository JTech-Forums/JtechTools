# frozen_string_literal: true

require "rails_helper"

# End-to-end coverage for the composer precheck prompts: the per-category
# "before a new topic" prompt and the per-topic "before a reply" prompt.
# Screenshots are written to tmp/capybara/ for the CI artifact.
RSpec.describe "Precheck prompt flows", type: :system do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category, title: "Existing app thread") }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "The original post in this thread.") }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.precheck_new_topic_enabled = true
    SiteSetting.topic_reply_prompt_enabled = true
    SiteSetting.topic_footer_message_enabled = true
    SiteSetting.min_topic_title_length = 5
    SiteSetting.min_first_post_length = 5
    SiteSetting.min_post_length = 5
    SiteSetting.title_min_entropy = 1
    SiteSetting.body_min_entropy = 1
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

  context "the per-category new-topic prompt" do
    before do
      category.custom_fields[
        "mod_category_new_topic_prompt"
      ] = "Before posting: is this a brand-new app, or a duplicate of an " \
        "existing thread?"
      category.save_custom_fields(true)
    end

    def open_new_topic_in(target_category)
      visit("/")
      find("#create-topic").click
      expect(page).to have_css(".d-editor-input", wait: 10)
      category_chooser = PageObjects::Components::SelectKit.new(".category-chooser")
      category_chooser.expand
      category_chooser.select_row_by_value(target_category.id)
    end

    it "warns when starting a new topic and supports Go back then Post anyway" do
      sign_in(admin)
      open_new_topic_in(category)

      find("#reply-title").fill_in(with: "My brand new app release")
      find(".d-editor-input").fill_in(with: "Details about my new app go here.")
      shot("27_new_topic_composer_in_category")

      find(".save-or-cancel .create").click
      expect(page).to have_css(".dialog-body", text: "is this a brand-new app", wait: 10)
      shot("28_new_topic_prompt_dialog")

      find(".dialog-footer button", text: "Go back").click
      expect(page).to have_css(".d-editor-input")
      shot("29_new_topic_prompt_go_back")

      find(".save-or-cancel .create").click
      expect(page).to have_css(".dialog-body", wait: 10)
      find(".dialog-footer button", text: "Post anyway").click
      expect(page).to have_css(".fancy-title", text: "My brand new app release", wait: 10)
      shot("30_new_topic_posted_after_confirm")
    end

    it "does not prompt in a category that has no prompt set" do
      plain_category = Fabricate(:category)
      sign_in(admin)
      open_new_topic_in(plain_category)

      find("#reply-title").fill_in(with: "A topic in a plain category")
      find(".d-editor-input").fill_in(with: "No prompt should appear here.")
      find(".save-or-cancel .create").click

      expect(page).to have_css(".fancy-title", text: "A topic in a plain category", wait: 10)
      expect(page).to have_no_css(".dialog-body")
      shot("31_no_prompt_plain_category")
    end
  end

  context "the per-topic reply prompt" do
    it "does not prompt when the topic has no reply prompt set" do
      sign_in(user)
      visit("/t/#{topic.slug}/#{topic.id}")
      expect(page).to have_css("#topic-title", wait: 10)

      find("#topic-footer-buttons .create", match: :first).click
      find(".d-editor-input").fill_in(with: "A reply with no prompt configured.")
      find(".save-or-cancel .create").click

      expect(page).to have_no_css(".dialog-body", wait: 5)
      shot("33_reply_no_prompt")
    end

    it "prompts with the moderator's message and posts after Post anyway" do
      topic.custom_fields[
        "mod_topic_reply_prompt"
      ] = "Is this an app upload or link to an app? If it's just a comment " \
        "or question, please post somewhere else."
      topic.save_custom_fields(true)

      sign_in(user)
      visit("/t/#{topic.slug}/#{topic.id}")
      expect(page).to have_css("#topic-title", wait: 10)

      find("#topic-footer-buttons .create", match: :first).click
      find(".d-editor-input").fill_in(with: "Here is my app upload reply.")
      find(".save-or-cancel .create").click

      expect(page).to have_css(".dialog-body", text: "Is this an app upload", wait: 10)
      shot("34_reply_prompt_dialog")

      find(".dialog-footer button", text: "Post anyway").click
      expect(page).to have_no_css(".dialog-body", wait: 10)
      shot("35_reply_posted_after_confirm")
    end

    it "renders a clickable link inside the reply precheck dialog" do
      topic.custom_fields[
        "mod_topic_reply_prompt"
      ] = "Please review the guidelines at https://example.com/guidelines " \
        "before replying."
      topic.save_custom_fields(true)

      sign_in(user)
      visit("/t/#{topic.slug}/#{topic.id}")
      expect(page).to have_css("#topic-title", wait: 10)

      find("#topic-footer-buttons .create", match: :first).click
      find(".d-editor-input").fill_in(with: "Here is my reply to the thread.")
      find(".save-or-cancel .create").click

      expect(page).to have_css(".dialog-body", wait: 10)
      # The shared linkify helper turns the http(s) URL into a real anchor.
      link = find(".dialog-body a[href='https://example.com/guidelines']", wait: 10)
      expect(link[:target]).to eq("_blank")
      expect(link[:rel]).to include("noopener")
      shot("88_precheck_dialog_clickable_link")
    end
  end
end
