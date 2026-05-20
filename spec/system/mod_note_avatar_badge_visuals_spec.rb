# frozen_string_literal: true

require "rails_helper"

# Close-up visual captures of the moderator-notes avatar pip across the
# different unread-count states. The badge lives on the current-user
# avatar in the header; these specs crop the screenshot to the `.d-header`
# bar so the badge is centred with enough context to read it.
#
# This file deliberately only screenshots — the behavioural coverage lives
# in `spec/system/mod_note_header_indicators_spec.rb`. We just need PNGs
# the reviewer can eyeball before merging.
RSpec.describe "Moderator-note avatar badge visuals", type: :system do
  fab!(:moderator)
  fab!(:category)

  before { SiteSetting.mod_categories_enabled = true }

  # Crop to the header bar if the driver supports element-level screenshots;
  # otherwise fall back to a full-page screenshot so the spec still produces
  # an artefact in CI.
  def avatar_shot(name)
    begin
      Timeout.timeout(5) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
      # Slow image — capture anyway.
    end

    path = "tmp/capybara/#{name}.png"
    begin
      el = find(".d-header", wait: 5)
      el.native.save_screenshot(path)
    rescue StandardError
      page.save_screenshot(path)
    end
  end

  # Build N topics, each with an unseen note activity timestamp. The
  # serializer counts `TopicCustomField` rows whose `value > seen_at`, so
  # this is the most reliable way to force `mod_note_unread_count` to N.
  def seed_unread_notes(count, base_time: Time.zone.now)
    count.times do |i|
      topic = Fabricate(:topic, category: category, title: "Mod note thread #{i + 1}")
      Fabricate(:post, topic: topic, raw: "Body for thread #{i + 1}.")
      topic.custom_fields["mod_topic_private_note"] = "Note #{i + 1}."
      topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
      topic.custom_fields["mod_topic_private_note_activity_at"] = (base_time + i.seconds).iso8601
      topic.save_custom_fields(true)
    end
  end

  # Force seen_at to "now+future" so any existing notes don't bleed in.
  def reset_seen_to_future
    moderator.custom_fields[DiscourseModCategories::USER_NOTES_SEEN_FIELD] = 1.hour.from_now.iso8601
    moderator.save_custom_fields(true)
  end

  # Wait until the pip reports the expected count via its data-count
  # attribute. The pip renders its number via a CSS `::before` pseudo, so
  # textContent is empty; `data-count` is the source of truth.
  def wait_for_pip_count(expected_label)
    Timeout.timeout(15) do
      loop do
        count =
          page
            .evaluate_script("document.querySelector('.mod-note-avatar-pip')?.dataset.count || ''")
            .to_s
            .strip
        break if count == expected_label
        sleep 0.2
      end
    end
  end

  def wait_for_pip_absent
    Timeout.timeout(15) do
      loop do
        visible = page.evaluate_script("!!document.querySelector('.mod-note-avatar-pip.visible')")
        break unless visible
        sleep 0.2
      end
    end
  end

  it "captures the avatar with no unread notes" do
    reset_seen_to_future
    sign_in(moderator)

    visit("/")
    expect(page).to have_css(".d-header .header-dropdown-toggle.current-user", wait: 10)
    wait_for_pip_absent
    avatar_shot("193_avatar_badge_no_unread")
  end

  it "captures the avatar with exactly 1 unread note" do
    seed_unread_notes(1)
    sign_in(moderator)

    visit("/")
    expect(page).to have_css(".mod-note-avatar-pip.visible", wait: 10)
    wait_for_pip_count("1")
    avatar_shot("194_avatar_badge_one_unread")
  end

  it "captures the avatar with 5 unread notes" do
    seed_unread_notes(5)
    sign_in(moderator)

    visit("/")
    expect(page).to have_css(".mod-note-avatar-pip.visible", wait: 10)
    wait_for_pip_count("5")
    avatar_shot("195_avatar_badge_five_unread")
  end

  it "captures the avatar with 12 unread notes (overflow renders as 9+)" do
    seed_unread_notes(12)
    sign_in(moderator)

    visit("/")
    expect(page).to have_css(".mod-note-avatar-pip.visible", wait: 10)
    wait_for_pip_count("9+")
    avatar_shot("196_avatar_badge_nine_plus_overflow")
  end

  it "captures the avatar after the shield tab clears the badge" do
    seed_unread_notes(3)
    sign_in(moderator)

    visit("/")
    expect(page).to have_css(".mod-note-avatar-pip.visible", wait: 10)
    wait_for_pip_count("3")

    # Open the user menu, click the shield tab, wait for the seen-ack to
    # fire and the badge to clear, then close the menu and screenshot.
    find(".header-dropdown-toggle.current-user").click
    expect(page).to have_css("#user-menu-button-discourse-mod-notes", wait: 10)
    find("#user-menu-button-discourse-mod-notes").click
    expect(page).to have_css(".mod-notes-panel", wait: 10)

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

    find("body").send_keys(:escape)
    wait_for_pip_absent
    avatar_shot("197_avatar_badge_after_seen")
  end
end
