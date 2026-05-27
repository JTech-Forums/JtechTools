# frozen_string_literal: true

require "rails_helper"

# Visual captures of the mod-note + whisper-bump behaviors so a reviewer
# can eyeball each from CI without spinning up a local Discourse. PNGs
# are written into `tmp/capybara/feature_screenshots/` and picked up by
# the `feature-screenshots.yml` workflow's `actions/upload-artifact@v6`
# step (`if: always()` — uploaded regardless of pass/fail).
#
# Scope: this spec is intentionally focused on the features actively
# under development (mod-note anchor + per-reply fan-out, audience-aware
# whisper bumping). Earlier broad-coverage scenarios were trimmed so the
# CI artifact stays small and every shot has a clear reviewer purpose.
RSpec.describe "Feature screenshots" do
  fab!(:admin) { Fabricate(:admin, username: "screen_admin") }
  fab!(:moderator) { Fabricate(:moderator, username: "screen_mod") }
  fab!(:other_moderator, :moderator) { Fabricate(:moderator, username: "screen_other_mod") }
  fab!(:author, :user) { Fabricate(:user, username: "screen_author") }
  fab!(:audience_user, :user) { Fabricate(:user, username: "screen_audience") }
  fab!(:stranger, :user) { Fabricate(:user, username: "screen_stranger") }
  fab!(:category)

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:participants_field) { DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD }
  let(:nwba_field) { DiscourseModCategories::TOPIC_NON_WHISPER_BUMPED_AT_FIELD }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.min_post_length = 5
    SiteSetting.body_min_entropy = 1
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    Group.refresh_automatic_groups!
    SiteSetting.approve_unless_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

    FileUtils.mkdir_p(File.join(Rails.root, "tmp/capybara/feature_screenshots"))
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
      # Capture anyway rather than failing on a slow image.
    end
    path = File.join(Rails.root, "tmp/capybara/feature_screenshots/#{name}.png")
    page.save_screenshot(path)
  end

  # Seeds a topic with a moderator note (default bottom placement) and
  # optional staff replies. Returns the saved topic.
  def seed_topic_with_note(title:, note:, position: "bottom", replies: [], filler_posts: 0)
    topic = Fabricate(:topic, category: category, title: title)
    Fabricate(:post, topic: topic, user: author, raw: "OP body for #{title}.")
    filler_posts.times do |i|
      Fabricate(
        :post,
        topic: topic,
        user: author,
        raw: "Filler reply ##{i + 1} keeping the thread long.",
      )
    end
    topic.custom_fields["mod_topic_private_note"] = note
    topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
    topic.custom_fields["mod_topic_private_note_position"] = position
    topic.custom_fields["mod_topic_private_note_created_at"] = 30.minutes.ago.iso8601
    topic.custom_fields["mod_topic_private_note_activity_at"] = Time.zone.now.iso8601
    topic.custom_fields["mod_topic_private_note_replies"] = replies if replies.any?
    topic.save_custom_fields(true)
    topic
  end

  # Builds a single mod-note bell notification of either kind ("note" or
  # "reply"), pointing at the topic's note section or a specific reply.
  def fab_mod_note_notification(user:, topic:, kind: "note", reply_id: nil, excerpt: nil)
    anchor = kind == "reply" ? "#mod-private-note-reply-#{reply_id}" : "#mod-private-note"
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: user.id,
      topic_id: topic.id,
      post_number: topic.reload.highest_post_number,
      high_priority: true,
      data: {
        topic_title: topic.title,
        display_username: moderator.username,
        mod_note: true,
        mod_note_kind: kind,
        reply_id: reply_id,
        excerpt: excerpt || topic.custom_fields["mod_topic_private_note"].to_s,
        url: "#{topic.relative_url}/#{topic.highest_post_number}#{anchor}",
        message:
          (
            if kind == "reply"
              "discourse_mod_categories.note_reply_notification"
            else
              "discourse_mod_categories.note_notification"
            end
          ),
        title:
          (
            if kind == "reply"
              "discourse_mod_categories.note_reply_notification_title"
            else
              "discourse_mod_categories.note_notification_title"
            end
          ),
      }.to_json,
    )
  end

  # ──────────────────────────────────────────────────────────────────────
  # Mod-note rendering on a topic page (renumbered "7-10" so the file
  # filenames line up with reviewer expectations).
  # ──────────────────────────────────────────────────────────────────────

  it "7. captures the mod-private-note rendered ABOVE the post stream (top placement)" do
    topic =
      seed_topic_with_note(
        title: "Mod note top placement demo",
        note: "Pinned at the top so staff see it before posts.",
        position: "top",
      )

    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".mod-private-note", wait: 15)
    shot("07_mod_note_top_placement")
  end

  it "8. captures a mod-note thread with multiple staff replies" do
    topic =
      seed_topic_with_note(
        title: "Mod note reply thread demo",
        note: "Triage starts here.",
        replies: [
          {
            "id" => "demo-rep-001",
            "user_id" => moderator.id,
            "raw" => "I'll DM the user and ask for context.",
            "created_at" => 90.minutes.ago.iso8601,
          },
          {
            "id" => "demo-rep-002",
            "user_id" => other_moderator.id,
            "raw" => "Sounds good — watching the next reply.",
            "created_at" => 60.minutes.ago.iso8601,
          },
          {
            "id" => "demo-rep-003",
            "user_id" => admin.id,
            "raw" => "Resolved on my end, closing the loop.",
            "created_at" => 30.minutes.ago.iso8601,
          },
        ],
      )

    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".mod-private-note-reply", count: 3, wait: 15)
    shot("08_mod_note_thread_with_replies")
  end

  it "9. captures the user-menu shield tab listing notes from multiple topics" do
    # Titles must be >= min_topic_title_length (15 by default) or
    # Fabricate(:topic, ...) raises ActiveRecord::RecordInvalid before
    # the test ever hits the browser — the blank-page failure shot in
    # the previous CI run was Capybara capturing about:blank because no
    # `visit` had happened yet.
    3.times do |i|
      seed_topic_with_note(
        title: "Triage topic #{i + 1} needs follow-up",
        note: "Triage note #{i + 1} — needs follow-up.",
      )
    end

    sign_in(admin)
    visit("/")
    expect(page).to have_css(".d-header", wait: 15)
    find(".header-dropdown-toggle.current-user button", match: :first).click
    # Discourse core renders `id="user-menu-button-<tab.id>"` on every
    # registered user-menu tab button — matches the proven pattern from
    # moderator_messages_spec.rb and gallery_expansion_spec.rb.
    expect(page).to have_css("#user-menu-button-discourse-mod-notes", wait: 15)
    find("#user-menu-button-discourse-mod-notes").click
    expect(page).to have_css(".mod-notes-panel .mod-notes-item", minimum: 3, wait: 15)
    sleep 0.3
    shot("09_shield_tab_with_multiple_notes")
  end

  it "10. captures a bell reply notification rendering the reply excerpt as description" do
    topic = Fabricate(:topic, category: category, title: "Bell reply excerpt demo")
    Fabricate(:post, topic: topic, user: author, raw: "OP for bell reply excerpt demo.")
    fab_mod_note_notification(
      user: admin,
      topic: topic,
      kind: "reply",
      reply_id: "bell-excerpt-001",
      excerpt:
        "Following up on the abuse report — please look at the new screenshot the user uploaded.",
    )

    sign_in(admin)
    visit("/")
    expect(page).to have_css(".d-header", wait: 15)
    find(".header-dropdown-toggle.current-user button", match: :first).click
    expect(page).to have_css(".notification.custom", wait: 10)
    sleep 0.3
    shot("10_bell_reply_notification_shows_excerpt")
  end

  # ──────────────────────────────────────────────────────────────────────
  # Bell-notification click-through (renumbered "11-12").
  # ──────────────────────────────────────────────────────────────────────

  it "11. captures stacked per-reply mod-note notifications in the bell" do
    topic = seed_topic_with_note(title: "Stacked replies demo", note: "Please review this thread.")

    %w[r-aaaa r-bbbb r-cccc].each_with_index do |reply_id, index|
      fab_mod_note_notification(
        user: admin,
        topic: topic,
        kind: "reply",
        reply_id: reply_id,
        excerpt: ["First reply body.", "Second reply body.", "Third reply body."][index],
      )
    end

    sign_in(admin)
    visit("/")
    expect(page).to have_css(".d-header", wait: 15)
    find(".header-dropdown-toggle.current-user button", match: :first).click
    expect(page).to have_css(".notification.custom", wait: 10)
    sleep 0.5
    shot("11_bell_stacked_reply_notifications")
  end

  it "12. captures a reply notification scrolling into a 15-post thread with bottom mod note" do
    # 15 real posts so the mod-note panel sits well below the initial
    # viewport — clicking the reply notification has to actually scroll,
    # not just land on a single-post topic.
    reply_id = "long-thread-reply-001"
    topic =
      seed_topic_with_note(
        title: "Long thread reply anchor demo",
        note: "Top-level moderator note pinned to the bottom of the long thread.",
        filler_posts: 14,
        replies: [
          {
            "id" => reply_id,
            "user_id" => moderator.id,
            "raw" => "The reply this notification points to — should be the focus on click.",
            "created_at" => 5.minutes.ago.iso8601,
          },
        ],
      )
    fab_mod_note_notification(
      user: admin,
      topic: topic,
      kind: "reply",
      reply_id: reply_id,
      excerpt: "The reply this notification points to.",
    )

    sign_in(admin)
    visit("/")
    expect(page).to have_css(".d-header", wait: 15)
    find(".header-dropdown-toggle.current-user button", match: :first).click
    expect(page).to have_css(".notification.custom", wait: 10)
    find(".notification.custom a", match: :first).click

    expect(page).to have_css("#mod-private-note-reply-#{reply_id}", wait: 15)
    # Give the deferred scrollIntoView (~250ms) plus rendering settle time.
    sleep 1.0
    shot("12_reply_notification_scroll_in_long_thread")
  end

  # ──────────────────────────────────────────────────────────────────────
  # Audience-aware whisper bumping on /latest. Two paired scenarios that
  # prove the same topic appears in different positions depending on
  # whether the viewer is in the whisper's audience.
  # ──────────────────────────────────────────────────────────────────────

  def seed_audience_aware_bump_scenario
    # Two topics seeded with a clear baseline ordering:
    #   public_topic   bumped 30 min ago (older)
    #   whisper_topic  bumped 5 min ago (newer) — by a whisper visible to audience_user only
    # The whisper-bump fix should:
    #   * Keep whisper_topic at top for audience_user (and staff).
    #   * Demote whisper_topic below public_topic for stranger.
    public_topic = Fabricate(:topic, category: category, title: "Public conversation")
    Fabricate(:post, topic: public_topic, user: author, raw: "Newest *public* post in the list.")
    ::Topic.where(id: public_topic.id).update_all(
      bumped_at: 30.minutes.ago,
      last_posted_at: 30.minutes.ago,
    )

    whisper_topic = Fabricate(:topic, category: category, title: "Topic with whisper at bottom")
    Fabricate(:post, topic: whisper_topic, user: author, raw: "Public OP for whisper topic.")
    Fabricate(:post, topic: whisper_topic, user: author, raw: "Public reply on whisper topic.")
    whisper =
      Fabricate(
        :post,
        topic: whisper_topic,
        user: moderator,
        raw: "Staff-only whisper most recent.",
      )
    whisper.custom_fields[targets_field] = [audience_user.id]
    whisper.save_custom_fields(true)
    whisper_topic.custom_fields[participants_field] = [audience_user.id]

    # Backdate the public posts BEFORE reading their max(created_at) for the
    # non-whisper-bumped-at stamp. Without this, the public posts have
    # created_at ≈ now, the NWBA stamp becomes "now", and the modifier's
    # demotion still puts whisper_topic above public_topic (whose bumped_at
    # is 30 min ago) — defeating the test premise. Mirrors the request
    # spec's update_columns(created_at: 1.hour.ago) pattern.
    whisper_topic.posts.where.not(id: whisper.id).update_all(created_at: 1.hour.ago)
    last_public_post_time = whisper_topic.posts.where.not(id: whisper.id).maximum(:created_at)
    whisper_topic.custom_fields[nwba_field] = last_public_post_time.iso8601
    whisper_topic.save_custom_fields(true)

    # Roll back highest_post_number (mirrors on(:post_created)) so the
    # unread-badge math is also audience-aware for this scenario.
    non_whisper_max =
      whisper_topic.posts.where.not(id: whisper.id).where(deleted_at: nil).maximum(:post_number)
    ::Topic.where(id: whisper_topic.id).update_all(
      bumped_at: 5.minutes.ago,
      last_posted_at: 5.minutes.ago,
      highest_post_number: non_whisper_max,
    )

    [whisper_topic, public_topic]
  end

  it "13. captures /latest for an AUDIENCE member — whispered topic at the top" do
    whisper_topic, _public_topic = seed_audience_aware_bump_scenario

    sign_in(audience_user)
    visit("/latest")
    expect(page).to have_css(".topic-list-item", minimum: 2, wait: 15)
    # The whispered topic should be the first item — proves the audience
    # member still sees the whisper-bump.
    expect(page).to have_css(
      ".topic-list-item:first-of-type a.title[href*='#{whisper_topic.slug}']",
      wait: 5,
    )
    shot("13_latest_audience_user_sees_whisper_at_top")
  end

  it "14. captures /latest for a NON-AUDIENCE viewer — whispered topic demoted" do
    whisper_topic, public_topic = seed_audience_aware_bump_scenario

    sign_in(stranger)
    visit("/latest")
    expect(page).to have_css(".topic-list-item", minimum: 2, wait: 15)
    # The public_topic should now appear above the whisper_topic — proves
    # the non-audience viewer doesn't see ghost activity from the whisper.
    expect(page).to have_css(
      ".topic-list-item:first-of-type a.title[href*='#{public_topic.slug}']",
      wait: 5,
    )
    shot("14_latest_non_audience_user_sees_public_topic_first")
  end

  # ──────────────────────────────────────────────────────────────────────
  # CSS sanity check: confirm whisper.scss is still loading and styling
  # the whisper banner on a posted whisper. If this shot ever lands
  # unstyled, the same SCSS-pipeline regression that bit us last round
  # is back and any new styles added to whisper.scss are at risk.
  # ──────────────────────────────────────────────────────────────────────

  it "15. captures the whisper banner styling on a posted whisper (CSS sanity)" do
    topic = Fabricate(:topic, category: category, title: "Whisper banner CSS check")
    Fabricate(:post, topic: topic, user: author, raw: "OP body for the visual capture.")
    Fabricate(:post, topic: topic, user: author, raw: "Public reply visible to everyone.")
    whisper = Fabricate(:post, topic: topic, user: moderator, raw: "Mod-only whisper body.")
    whisper.custom_fields[targets_field] = [audience_user.id]
    whisper.save_custom_fields(true)
    topic.custom_fields[participants_field] = [audience_user.id]
    topic.save_custom_fields(true)

    non_whisper_max =
      Post
        .where(topic_id: topic.id, deleted_at: nil)
        .where.not(id: PostCustomField.where(name: targets_field).select(:post_id))
        .maximum(:post_number)
    Topic.where(id: topic.id).update_all(highest_post_number: non_whisper_max) if non_whisper_max

    sign_in(audience_user)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".mod-whisper-banner", wait: 15)
    # If the banner exists but is invisible / unstyled, the screenshot
    # will surface it; the visual sanity check is the whole point.
    sleep 0.3
    shot("15_whisper_banner_css_sanity")
  end

  # ──────────────────────────────────────────────────────────────────────
  # Post-PR-#12 additions: "Viewed by N" avatar pill at the bottom of
  # the mod-note panel + the click-to-open popover with full viewer
  # details (avatar, name, relative-time).
  # ──────────────────────────────────────────────────────────────────────

  # Seeds a panel with prior viewers (other than the signed-in user) so
  # the pill renders multiple avatars on first paint, before the current
  # user's own POST-on-mount lands.
  def seed_panel_with_viewers(topic, viewers)
    topic.custom_fields[DiscourseModCategories::TOPIC_NOTE_VIEWERS_FIELD] = viewers.map do |user|
      {
        "user_id" => user.id,
        "username" => user.username,
        "name" => user.name || user.username,
        "avatar_template" => user.avatar_template,
        "viewed_at" => rand(1..40).minutes.ago.iso8601,
      }
    end
    topic.save_custom_fields(true)
  end

  it "16. captures the mod-note panel with the 'Viewed by' avatar pill" do
    topic =
      seed_topic_with_note(
        title: "Mod note viewers pill demo",
        note: "Pinned at the bottom — staff who view this panel are stacked below.",
      )
    seed_panel_with_viewers(topic, [moderator, other_moderator, author])

    sign_in(admin)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".mod-private-note-viewers-pill", wait: 15)
    # Each prior viewer's avatar + the current user's after the
    # record-on-mount POST resolves.
    expect(page).to have_css(".mod-private-note-viewers-pill-avatar", minimum: 3, wait: 10)
    sleep 0.3
    shot("16_mod_note_viewers_pill_closed")
  end

  it "17. captures the mod-note viewers popover open with the full list" do
    topic =
      seed_topic_with_note(
        title: "Mod note viewers popover demo",
        note: "Pinned at the bottom — click the avatar stack to see who viewed.",
      )
    seed_panel_with_viewers(topic, [moderator, other_moderator, author, audience_user])

    sign_in(admin)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".mod-private-note-viewers-pill", wait: 15)
    find(".mod-private-note-viewers-pill").click
    expect(page).to have_css(".mod-private-note-viewers-list-item", minimum: 4, wait: 5)
    sleep 0.3
    shot("17_mod_note_viewers_popover_open")
  end
end
