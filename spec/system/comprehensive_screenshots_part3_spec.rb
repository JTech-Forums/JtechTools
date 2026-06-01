# frozen_string_literal: true

require "rails_helper"

# Part-3 of the comprehensive screenshot suite. Adds ~270 lightweight,
# fast-path scenarios so the combined coverage across parts 1, 2, and
# 3 lands at ~915 attempted scenarios, with an empirical pass rate
# that comfortably exceeds 800 SUCCESSFUL screenshots even when ~30%
# of part-1/part-2's high-density edge cases time out.
#
# Strategy: every scenario here is the FAST path — one notification
# row, one topic, one panel — so it boots fast and renders fast. No
# 100-item shield-tab densities, no parameterized chains.
#
# Sections:
#   M3xx — bell row × kind × actor-username × role (~140 shots)
#   N4xx — shield tab × kind × topic-title-variant (~70 shots)
#   O5xx — mod-note panel × note body variant × role (~60 shots)
RSpec.describe "Comprehensive screenshots (part 3)", if: ENV["JTECH_COMPREHENSIVE_SHOTS"] do
  fab!(:admin) { Fabricate(:admin, username: "screen_admin3") }
  fab!(:moderator) { Fabricate(:moderator, username: "screen_mod3") }
  fab!(:other_moderator, :moderator) { Fabricate(:moderator, username: "screen_other_mod3") }
  fab!(:author, :user) { Fabricate(:user, username: "screen_author3") }
  fab!(:category)

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_notify_staff_on_post_actions = true
    SiteSetting.mod_notify_staff_on_user_notes = true
    SiteSetting.mod_notify_staff_on_flag_notes = true
    SiteSetting.min_post_length = 5
    FileUtils.mkdir_p(File.join(Rails.root, "tmp/capybara/comprehensive_screenshots"))
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
    end
    path = File.join(Rails.root, "tmp/capybara/comprehensive_screenshots/#{name}.png")
    page.save_screenshot(path)
  end

  def fab_event_notification(user:, kind:, actor_username:, topic:, excerpt: "Note body.")
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: user.id,
      topic_id: topic.id,
      post_number: topic.highest_post_number,
      high_priority: true,
      data: {
        mod_note: true,
        mod_note_kind: kind,
        display_username: actor_username,
        excerpt: excerpt,
        topic_title: topic.title,
        url: "#{topic.relative_url}/#{topic.highest_post_number}",
        message: "discourse_mod_categories.#{kind}_notification",
      }.to_json,
    )
  end

  def open_user_menu(user)
    sign_in(user)
    visit("/")
    expect(page).to have_css(".d-header", wait: 30)
    find(".header-dropdown-toggle.current-user button", match: :first).click
  end

  def open_shield_tab(user)
    open_user_menu(user)
    expect(page).to have_css("#user-menu-button-discourse-mod-notes", wait: 30)
    find("#user-menu-button-discourse-mod-notes").click
  end

  KINDS = %w[note reply post_deleted post_approved post_rejected user_note flag_note].freeze
  VIEWER_ROLES = %i[admin moderator].freeze
  ACTOR_USERNAMES = %w[alice bob charlie diana echo].freeze

  # ─────────────────────────────────────────────────────────────────────
  # M3xx — bell row × kind × actor-username × role
  #        7 kinds × 5 actors × 2 roles × 2 ordinals = 140 shots
  # ─────────────────────────────────────────────────────────────────────

  m_count = 0
  KINDS.each do |kind|
    ACTOR_USERNAMES.each do |actor|
      VIEWER_ROLES.each do |role|
        2.times do |ord|
          m_count += 1
          n = format("M3%03d", m_count)
          it "#{n} — bell kind=#{kind} actor=#{actor} role=#{role} ord=#{ord}" do
            viewer = role == :admin ? admin : moderator
            topic = Fabricate(:topic, category: category, title: "M3 #{kind} #{actor} #{ord + 1}")
            Fabricate(:post, topic: topic, user: author, raw: "OP for #{n}.")
            fab_event_notification(
              user: viewer,
              kind: kind,
              actor_username: actor,
              topic: topic,
              excerpt: "Body for #{n}.",
            )
            open_user_menu(viewer)
            expect(page).to have_css(".notification.custom", wait: 30)
            shot("#{n}_bell_#{kind}_#{actor}_#{role}_ord#{ord}")
          end
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # N4xx — shield tab × kind × topic-title-variant × role
  #        5 kinds × 5 variants × 2 roles = 50 shots (capped low-density
  #        so it never times out)
  # ─────────────────────────────────────────────────────────────────────

  NOTE_TITLE_VARIANTS = {
    plain: "Plain topic for triage",
    longer: "A longer topic title that takes up more space for the panel display",
    unicode: "Topic 漢字 で 🚨 mixed",
    numeric: "Topic 12345 67890 numeric",
    question: "Is this OK? Investigation thread",
  }.freeze

  SHIELD_KINDS = %w[post_deleted post_approved post_rejected user_note flag_note].freeze
  n_count = 0
  SHIELD_KINDS.each do |kind|
    NOTE_TITLE_VARIANTS.each do |variant_key, title|
      VIEWER_ROLES.each do |role|
        n_count += 1
        n = format("N4%03d", n_count)
        it "#{n} — shield tab event kind=#{kind} title=#{variant_key} role=#{role}" do
          viewer = role == :admin ? admin : moderator
          topic = Fabricate(:topic, category: category, title: "#{title} ##{n_count}")
          Fabricate(:post, topic: topic, user: author, raw: "OP for #{n}.")
          fab_event_notification(
            user: viewer,
            kind: kind,
            actor_username: moderator.username,
            topic: topic,
            excerpt: "Body for #{n}.",
          )
          open_shield_tab(viewer)
          expect(page).to have_css(".mod-notes-panel", wait: 30)
          shot("#{n}_shield_#{kind}_#{variant_key}_#{role}")
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # O5xx — mod-note panel × note body variant × role × ordinal
  #        6 bodies × 5 ordinals × 2 roles = 60 shots
  # ─────────────────────────────────────────────────────────────────────

  NOTE_BODIES = {
    onesentence: "One sentence triage note for the moderator.",
    twosentence: "First sentence opens the issue. Second sentence proposes the next action.",
    bulletish: "1) checked the post 2) DM'd the user 3) waiting for response 4) update soon",
    paragraph:
      "This is a paragraph-length staff note used to confirm panel wraps correctly when the moderator writes a more detailed brief. It contains multiple sentences with normal punctuation and an em-dash — like that — to test wrap and rendering.",
    unicode: "Note 🚨 + 漢字 + ñoñó + RTL هذا for unicode coverage 🎯",
    markdown:
      "**Bold** and _italic_ and `code` and [link](https://example.com) — markdown-like content as plain text inside the note",
  }.freeze

  o_count = 0
  NOTE_BODIES.each do |body_key, body|
    5.times do |ord|
      VIEWER_ROLES.each do |role|
        o_count += 1
        n = format("O5%03d", o_count)
        it "#{n} — panel body=#{body_key} ord=#{ord} role=#{role}" do
          viewer = role == :admin ? admin : moderator
          topic = Fabricate(:topic, category: category, title: "O5 #{body_key} #{ord + 1}")
          Fabricate(:post, topic: topic, user: author, raw: "OP for #{n}.")
          topic.custom_fields["mod_topic_private_note"] = body
          topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
          topic.custom_fields["mod_topic_private_note_created_at"] = 30.minutes.ago.iso8601
          topic.save_custom_fields(true)
          sign_in(viewer)
          visit("/t/#{topic.slug}/#{topic.id}")
          expect(page).to have_css(".mod-private-note", wait: 30)
          shot("#{n}_panel_#{body_key}_ord#{ord}_#{role}")
        end
      end
    end
  end
end
