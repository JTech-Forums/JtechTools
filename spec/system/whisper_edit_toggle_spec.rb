# frozen_string_literal: true

require "rails_helper"

# End-to-end Capybara coverage for the staff whisper-toggle-on-edit
# flow. The unit pieces are covered by other specs:
#
#   * `update_post_whisper_spec` covers the server endpoint's contract
#     (arm/disarm/authz/edge cases).
#   * `feature_screenshots_spec` captures the visual states (composer
#     open, modal open, post-rendered-as-whisper, non-staff no-button).
#
# What was missing — and what this spec covers — is the FRONTEND
# CHAIN: that the `model:composer#save` patch in mod-whisper.js
# actually fires the PUT after a staff edit save when the modal
# marked the state dirty. Without this, the modal could open, the
# composer could save, and the whisper toggle would silently drop on
# the floor with no Ruby spec able to catch it.
RSpec.describe "Whisper edit toggle (frontend save chain)" do
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:target, :user)
  fab!(:topic) { Fabricate(:topic, title: "Edit whisper toggle e2e demo") }

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:groups_field) { DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD }
  let(:badges_field) { DiscourseModCategories::POST_WHISPER_TARGET_BADGES_FIELD }
  let(:armed_param) { DiscourseModCategories::POST_WHISPER_ARMED_PARAM }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    Group.refresh_automatic_groups!
  end

  # Click the post's edit pencil. The "..." menu may need to be opened
  # first on some Discourse releases; both paths are tried.
  def open_edit_composer(post)
    article = find("#post_#{post.post_number}")
    begin
      article.find(".show-more-actions", match: :first).click
    rescue Capybara::ElementNotFound
      # Already-expanded post action row; no need to open the "..." menu.
    end
    article.find(".edit", match: :first).click
    expect(page).to have_css(".d-editor-input", wait: 15)
  end

  def click_whisper_toolbar_button
    find(
      ".d-editor-button-bar button.mod-whisper-target, " \
        ".d-editor-button-bar button[title='" \
        "#{I18n.t("js.discourse_mod_categories.whisper.toolbar_title")}']",
      match: :first,
    ).click
    expect(page).to have_css(".mod-whisper-target-modal", wait: 10)
  end

  it "staff edit on a regular post → confirm whisper modal → save → post becomes a whisper" do
    regular_post =
      Fabricate(
        :post,
        topic: topic,
        user: author,
        raw: "Regular public post, about to be toggled to a whisper.",
      )
    expect(regular_post.custom_fields).not_to have_key(targets_field)

    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".topic-post", wait: 15)

    open_edit_composer(regular_post)
    click_whisper_toolbar_button

    # Confirm with an empty audience — staff-only whisper-back. The
    # modal's `confirm()` sets `modWhisperDirty = true` and arms the
    # composer, which is the state the save patch keys off.
    within(".mod-whisper-target-modal") { find(".btn-primary.mod-whisper-confirm").click }
    expect(page).to have_no_css(".mod-whisper-target-modal", wait: 5)

    # Save the edit. The composer's `save()` resolves, then the
    # patched override chains the PUT to update_post_whisper.
    find(".save-edits", match: :first).click
    expect(page).to have_no_css(".d-editor-input", wait: 15)

    # Wait for the chained PUT to land. The composer's save promise
    # resolves before the PUT, so a fixed delay covers the race
    # without relying on a DOM signal that may not exist.
    sleep 2

    reloaded = regular_post.reload
    expect(reloaded.custom_fields).to have_key(targets_field)
  end

  it "staff edit on a whisper → clear modal → save → post becomes regular" do
    whispered =
      Fabricate(
        :post,
        topic: topic,
        user: author,
        raw: "Whispered post, about to be toggled BACK to regular.",
      )
    whispered.custom_fields[targets_field] = [target.id]
    whispered.save_custom_fields(true)
    expect(whispered.reload.custom_fields).to have_key(targets_field)

    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".topic-post", wait: 15)

    open_edit_composer(whispered)
    click_whisper_toolbar_button

    # The modal's Clear button — disarms and closes. Same dirty-flag
    # mechanism as confirm, but with `modWhisperArmed = false`.
    within(".mod-whisper-target-modal") do
      find(".btn-flat", text: I18n.t("js.discourse_mod_categories.whisper.clear")).click
    end
    expect(page).to have_no_css(".mod-whisper-target-modal", wait: 5)

    find(".save-edits", match: :first).click
    expect(page).to have_no_css(".d-editor-input", wait: 15)
    sleep 2

    reloaded = whispered.reload
    expect(reloaded.custom_fields).not_to have_key(targets_field)
    expect(reloaded.custom_fields).not_to have_key(groups_field)
    expect(reloaded.custom_fields).not_to have_key(badges_field)
  end

  it "edit without opening the whisper modal does NOT fire the PUT (dirty flag stays false)" do
    regular_post =
      Fabricate(
        :post,
        topic: topic,
        user: author,
        raw: "Regular public post — staff is just fixing a typo.",
      )

    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".topic-post", wait: 15)

    open_edit_composer(regular_post)
    # Just edit the raw, don't touch the whisper modal.
    page.execute_script(<<~JS)
      const editor = document.querySelector('.d-editor-input');
      if (editor) {
        editor.value = 'Fixed a typo in the regular post.';
        editor.dispatchEvent(new Event('input', { bubbles: true }));
      }
    JS

    find(".save-edits", match: :first).click
    expect(page).to have_no_css(".d-editor-input", wait: 15)
    sleep 2

    # The save chain's `if (editingPost && dirty && ...)` skipped — the
    # post should still be a regular post, no whisper rows.
    expect(regular_post.reload.custom_fields).not_to have_key(targets_field)
  end
end
