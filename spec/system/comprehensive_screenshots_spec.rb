# frozen_string_literal: true

require "rails_helper"

# Broad-coverage screenshot suite for visual review. Where
# feature_screenshots_spec.rb captures focused, hand-picked scenarios,
# this spec parameterizes across kinds × lengths × roles × panel states
# so a reviewer can eyeball the visual surface area of the staff-event
# notifications, shield tab, mod-note panel, bell dropdown, and smart
# search in one run.
#
# Output goes to `tmp/capybara/comprehensive_screenshots/<NN>_<name>.png`
# and is uploaded by the `comprehensive-screenshots.yml` workflow on
# manual dispatch. Numeric prefixes group related shots so the artifact
# is navigable as a filename-sorted list.
#
# Section index:
#   A1xx — bell notification row per kind × length × read/unread
#   B2xx — shield-tab panel: empty / single / mixed / scrollable / read
#   C3xx — mod-note panel on topic: placement × replies × viewers
#   D4xx — bell dropdown stacking & mixed-kind clustering
#   E5xx — smart search dropdown + results, on/off comparison
#   F6xx — edge cases: long names, unicode, empty states
#
# NB: this spec is SKIPPED by default so it doesn't slow ordinary CI.
# Toggle on via `JTECH_COMPREHENSIVE_SHOTS=1` (set by the dedicated
# workflow) or by running the spec file directly.
RSpec.describe "Comprehensive screenshots", if: ENV["JTECH_COMPREHENSIVE_SHOTS"] do
  fab!(:admin) { Fabricate(:admin, username: "screen_admin") }
  fab!(:moderator) { Fabricate(:moderator, username: "screen_mod") }
  fab!(:other_moderator, :moderator) { Fabricate(:moderator, username: "screen_other_mod") }
  fab!(:author, :user) { Fabricate(:user, username: "screen_author") }
  fab!(:category)

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.mod_notify_staff_on_post_actions = true
    SiteSetting.mod_notify_staff_on_user_notes = true
    SiteSetting.mod_notify_staff_on_flag_notes = true
    SiteSetting.smart_search_enabled = true
    SiteSetting.min_post_length = 5

    FileUtils.mkdir_p(File.join(Rails.root, "tmp/capybara/comprehensive_screenshots"))
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
      # capture anyway
    end
    path = File.join(Rails.root, "tmp/capybara/comprehensive_screenshots/#{name}.png")
    page.save_screenshot(path)
  end

  def short_excerpt
    "Short staff note for triage."
  end

  def medium_excerpt
    "Medium-length staff note describing what the moderator saw and the next action expected."
  end

  def long_excerpt
    "Long staff note used to validate that the bell row and the shield-tab row " \
      "wrap or truncate cleanly when the moderator pastes in a paragraph of context " \
      "instead of a single sentence — Discourse's defaults truncate at ~300 chars."
  end

  def empty_excerpt
    ""
  end

  def onechar_excerpt
    "."
  end

  def unicode_excerpt
    "Note 🚨 + 漢字 + ñoñó for unicode coverage 🎯"
  end

  # Builds one mod_note-flagged Notification for `user` with the given kind
  # + payload. Returns the row.
  def fab_event_notification(
    user:,
    kind:,
    topic: nil,
    excerpt: nil,
    url: nil,
    target_username: nil,
    read: false
  )
    data = {
      mod_note: true,
      mod_note_kind: kind,
      display_username: moderator.username,
      excerpt: excerpt || short_excerpt,
      topic_title: topic&.title,
      target_username: target_username,
      url: url || (topic && "#{topic.relative_url}/#{topic.highest_post_number}"),
      message: "discourse_mod_categories.#{kind}_notification",
    }
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: user.id,
      topic_id: topic&.id,
      post_number: topic&.highest_post_number,
      high_priority: true,
      read: read,
      data: data.to_json,
    )
  end

  def seed_topic_with_post
    topic = Fabricate(:topic, category: category, title: "Topic for screenshot scenarios")
    Fabricate(:post, topic: topic, user: author, raw: "OP body for screenshot scenarios.")
    topic
  end

  def open_user_menu
    visit("/")
    expect(page).to have_css(".d-header", wait: 30)
    find(".header-dropdown-toggle.current-user button", match: :first).click
  end

  def open_shield_tab
    open_user_menu
    expect(page).to have_css("#user-menu-button-discourse-mod-notes", wait: 30)
    find("#user-menu-button-discourse-mod-notes").click
  end

  # ─────────────────────────────────────────────────────────────────────
  # A. Bell notification row per kind × length × read/unread
  #    Each shot opens the bell, expects one notification of that kind
  #    to be visible, and captures the dropdown.
  # ─────────────────────────────────────────────────────────────────────

  KINDS = %w[note reply post_deleted post_approved post_rejected user_note flag_note].freeze
  LENGTHS = {
    short: :short_excerpt,
    medium: :medium_excerpt,
    long: :long_excerpt,
    empty: :empty_excerpt,
    onechar: :onechar_excerpt,
  }.freeze
  # Each shot is per (kind × length × read × viewer-role). Anonymous and
  # regular users can't see staff notifications, so only the two staff
  # roles iterate here. Roll-counter `a_count` produces sequential A1xx
  # names without manually counting.
  VIEWER_ROLES = %i[admin moderator].freeze

  a_count = 0
  KINDS.each do |kind|
    LENGTHS.each_key do |length_name|
      [false, true].each do |read|
        VIEWER_ROLES.each do |role|
          a_count += 1
          n = format("A1%03d", a_count)
          excerpt_method = LENGTHS[length_name]
          shot_name = "#{n}_#{kind}_#{length_name}_#{read ? "read" : "unread"}_#{role}"

          it "#{n} — bell row: kind=#{kind} length=#{length_name} read=#{read} role=#{role}" do
            viewer = role == :admin ? admin : moderator
            topic = seed_topic_with_post
            fab_event_notification(
              user: viewer,
              kind: kind,
              topic: topic,
              excerpt: send(excerpt_method),
              target_username: %w[user_note flag_note].include?(kind) ? author.username : nil,
              read: read,
            )
            sign_in(viewer)
            open_user_menu
            expect(page).to have_css(".notification.custom", wait: 30)
            shot(shot_name)
          end
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # B. Shield-tab panel states
  # ─────────────────────────────────────────────────────────────────────

  it "B201 — shield tab: empty state" do
    sign_in(admin)
    open_shield_tab
    expect(page).to have_css(".mod-notes-panel", wait: 30)
    shot("B201_shield_tab_empty")
  end

  it "B202 — shield tab: single topic-attached note" do
    topic = seed_topic_with_post
    topic.custom_fields["mod_topic_private_note"] = "Single topic note for triage."
    topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
    topic.custom_fields["mod_topic_private_note_activity_at"] = Time.zone.now.iso8601
    topic.save_custom_fields(true)
    sign_in(admin)
    open_shield_tab
    expect(page).to have_css(".mod-notes-panel .mod-notes-item", wait: 30)
    shot("B202_shield_tab_single_topic_note")
  end

  it "B203 — shield tab: three topic-attached notes" do
    3.times do |i|
      t = Fabricate(:topic, category: category, title: "Topic #{i + 1} needs triage")
      Fabricate(:post, topic: t, user: author, raw: "OP for topic #{i + 1}.")
      t.custom_fields["mod_topic_private_note"] = "Note #{i + 1} — needs eyes."
      t.custom_fields["mod_topic_private_note_user_id"] = moderator.id
      t.custom_fields["mod_topic_private_note_activity_at"] = (i + 1).hours.ago.iso8601
      t.save_custom_fields(true)
    end
    sign_in(admin)
    open_shield_tab
    expect(page).to have_css(".mod-notes-panel .mod-notes-item", minimum: 3, wait: 30)
    shot("B203_shield_tab_three_topic_notes")
  end

  %w[post_deleted post_approved post_rejected user_note flag_note].each_with_index do |kind, idx|
    n = format("B2%02d", 4 + idx)
    it "#{n} — shield tab: single #{kind} event notification" do
      topic = seed_topic_with_post
      fab_event_notification(
        user: admin,
        kind: kind,
        topic: %w[post_deleted post_approved].include?(kind) ? topic : nil,
        excerpt: short_excerpt,
        target_username: %w[user_note flag_note].include?(kind) ? author.username : nil,
        url: %w[post_rejected flag_note].include?(kind) ? "/review/1" : nil,
      )
      sign_in(admin)
      open_shield_tab
      expect(page).to have_css(".mod-notes-panel .mod-notes-item", wait: 30)
      shot("#{n}_shield_tab_#{kind}")
    end
  end

  it "B209 — shield tab: mixed topic-attached + event notifications" do
    topic = seed_topic_with_post
    topic.custom_fields["mod_topic_private_note"] = "Topic-attached note."
    topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
    topic.custom_fields["mod_topic_private_note_activity_at"] = 1.hour.ago.iso8601
    topic.save_custom_fields(true)
    %w[post_deleted user_note flag_note].each do |kind|
      fab_event_notification(
        user: admin,
        kind: kind,
        topic: kind == "post_deleted" ? topic : nil,
        target_username: kind == "user_note" || kind == "flag_note" ? author.username : nil,
      )
    end
    sign_in(admin)
    open_shield_tab
    expect(page).to have_css(".mod-notes-panel .mod-notes-item", minimum: 4, wait: 30)
    shot("B209_shield_tab_mixed_kinds")
  end

  it "B210 — shield tab: ten items requiring scroll" do
    10.times do |i|
      t = Fabricate(:topic, category: category, title: "Scrollable topic #{i + 1}")
      Fabricate(:post, topic: t, user: author, raw: "OP for scrollable topic #{i + 1}.")
      t.custom_fields["mod_topic_private_note"] = "Scroll item #{i + 1}."
      t.custom_fields["mod_topic_private_note_user_id"] = moderator.id
      t.custom_fields["mod_topic_private_note_activity_at"] = (i + 1).minutes.ago.iso8601
      t.save_custom_fields(true)
    end
    sign_in(admin)
    open_shield_tab
    expect(page).to have_css(".mod-notes-panel .mod-notes-item", minimum: 10, wait: 30)
    shot("B210_shield_tab_scrollable_ten")
  end

  # ─────────────────────────────────────────────────────────────────────
  # C. Mod-note panel on topic page (placement × replies × viewers)
  # ─────────────────────────────────────────────────────────────────────

  c_count = 0
  %w[top bottom].each do |position|
    %i[short medium long].each do |length_name|
      VIEWER_ROLES.each do |role|
        c_count += 1
        n = format("C3%03d", c_count)
        it "#{n} — mod-note panel: position=#{position} length=#{length_name} role=#{role}" do
          viewer = role == :admin ? admin : moderator
          topic = Fabricate(:topic, category: category, title: "Panel #{position} #{length_name}")
          Fabricate(:post, topic: topic, user: author, raw: "OP body for panel test.")
          topic.custom_fields["mod_topic_private_note"] = send("#{length_name}_excerpt")
          topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
          topic.custom_fields["mod_topic_private_note_position"] = position
          topic.custom_fields["mod_topic_private_note_created_at"] = 30.minutes.ago.iso8601
          topic.save_custom_fields(true)
          sign_in(viewer)
          visit("/t/#{topic.slug}/#{topic.id}")
          expect(page).to have_css(".mod-private-note", wait: 30)
          shot("#{n}_panel_#{position}_#{length_name}_#{role}")
        end
      end
    end
  end

  REPLY_COUNTS = [0, 1, 2, 3, 5, 7, 10].freeze
  REPLY_COUNTS.each do |reply_count|
    VIEWER_ROLES.each do |role|
      c_count += 1
      n = format("C3%03d", c_count)
      it "#{n} — mod-note panel: #{reply_count} replies role=#{role}" do
        viewer = role == :admin ? admin : moderator
        topic = Fabricate(:topic, category: category, title: "Panel with #{reply_count} replies")
        Fabricate(:post, topic: topic, user: author, raw: "OP body for replies test.")
        replies =
          Array.new(reply_count) do |i|
            {
              "id" => format("rep-%04d", i + 1),
              "user_id" => i.odd? ? other_moderator.id : moderator.id,
              "raw" => "Reply #{i + 1} body for visual review.",
              "created_at" => (reply_count - i).hours.ago.iso8601,
            }
          end
        topic.custom_fields["mod_topic_private_note"] = "Note with #{reply_count} replies."
        topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
        topic.custom_fields["mod_topic_private_note_replies"] = replies
        topic.save_custom_fields(true)
        sign_in(viewer)
        visit("/t/#{topic.slug}/#{topic.id}")
        expect(page).to have_css(".mod-private-note", wait: 30)
        shot("#{n}_panel_replies_#{reply_count}_#{role}")
      end
    end
  end

  VIEWER_COUNTS = [0, 1, 2, 3, 5, 8, 12].freeze
  VIEWER_COUNTS.each do |viewer_count|
    VIEWER_ROLES.each do |role|
      c_count += 1
      n = format("C3%03d", c_count)
      it "#{n} — mod-note panel: #{viewer_count} viewers role=#{role}" do
        viewer = role == :admin ? admin : moderator
        topic = Fabricate(:topic, category: category, title: "Panel with #{viewer_count} viewers")
        Fabricate(:post, topic: topic, user: author, raw: "OP for viewers test.")
        viewers =
          Array.new(viewer_count) do |i|
            u = Fabricate(:user, username: "viewer_#{viewer_count}_#{i}_#{role}")
            {
              "user_id" => u.id,
              "username" => u.username,
              "name" => u.name,
              "avatar_template" => u.avatar_template,
              "viewed_at" => (viewer_count - i).minutes.ago.iso8601,
            }
          end
        topic.custom_fields["mod_topic_private_note"] = "Note with #{viewer_count} viewers."
        topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
        topic.custom_fields["mod_topic_note_viewers"] = viewers
        topic.save_custom_fields(true)
        sign_in(viewer)
        visit("/t/#{topic.slug}/#{topic.id}")
        expect(page).to have_css(".mod-private-note", wait: 30)
        shot("#{n}_panel_viewers_#{viewer_count}_#{role}")
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # D. Bell dropdown: stacking + mixed kinds
  # ─────────────────────────────────────────────────────────────────────

  [3, 5, 10].each_with_index do |stack_count, s_idx|
    n = format("D4%02d", s_idx + 1)
    it "#{n} — bell: #{stack_count} stacked reply notifications" do
      topic = seed_topic_with_post
      stack_count.times do |i|
        fab_event_notification(
          user: admin,
          kind: "reply",
          topic: topic,
          excerpt: "Reply #{i + 1} body for stacking test.",
        )
      end
      sign_in(admin)
      open_user_menu
      expect(page).to have_css(".notification.custom", minimum: stack_count, wait: 30)
      shot("#{n}_bell_stacked_replies_#{stack_count}")
    end
  end

  it "D404 — bell: all 7 kinds in one dropdown" do
    topic = seed_topic_with_post
    KINDS.each do |kind|
      fab_event_notification(
        user: admin,
        kind: kind,
        topic: %w[note reply post_deleted post_approved].include?(kind) ? topic : nil,
        target_username: %w[user_note flag_note].include?(kind) ? author.username : nil,
        url: %w[post_rejected flag_note].include?(kind) ? "/review/1" : nil,
      )
    end
    sign_in(admin)
    open_user_menu
    expect(page).to have_css(".notification.custom", minimum: 7, wait: 30)
    shot("D404_bell_all_kinds_clustered")
  end

  # ─────────────────────────────────────────────────────────────────────
  # E. Smart search dropdown / results
  # ─────────────────────────────────────────────────────────────────────

  # Indexed smart search demos: enable SearchIndexer + reindex so synonym
  # expansion produces actual results instead of "No results found".
  SMART_SEARCH_TERMS = %w[kid behavior tantrum aba reinforcement noncompliance autism].freeze

  SMART_SEARCH_TERMS.each_with_index do |term, idx|
    n = format("E5%02d", 10 + idx)
    it "#{n} — smart search results page with index for '#{term}'" do
      SearchIndexer.enable
      t = Fabricate(:topic, category: category, title: "Helping my child with morning routines")
      p = Fabricate(:post, topic: t, user: author, raw: "Tips on child behavior and conduct.")
      SearchIndexer.index(p, force: true)
      SearchIndexer.index(t, force: true)
      sign_in(admin)
      visit("/search?q=#{term}")
      expect(page).to have_css(".search-results, .search-container, .no-results", wait: 30)
      shot("#{n}_smart_search_indexed_#{term}")
      SearchIndexer.disable
    end
  end

  it "E501 — smart search: dropdown with synonym match (kid → child)" do
    t1 = Fabricate(:topic, category: category, title: "Helping my child with morning routines")
    Fabricate(:post, topic: t1, user: author, raw: "Tips for working with a young child.")
    sign_in(admin)
    visit("/")
    find("#search-button").click
    expect(page).to have_css("input.search-query", wait: 10)
    find("input.search-query").set("kid")
    sleep 1.5
    shot("E501_smart_search_dropdown_synonym")
  end

  it "E502 — smart search: full results page with synonym match" do
    t1 = Fabricate(:topic, category: category, title: "Helping my child with morning routines")
    Fabricate(:post, topic: t1, user: author, raw: "Tips for working with a young child.")
    sign_in(admin)
    visit("/search?q=kid")
    expect(page).to have_css(".search-results", wait: 30)
    shot("E502_smart_search_results_page")
  end

  it "E503 — smart search disabled: baseline same query" do
    SiteSetting.smart_search_enabled = false
    t1 = Fabricate(:topic, category: category, title: "Helping my child with morning routines")
    Fabricate(:post, topic: t1, user: author, raw: "Tips for working with a young child.")
    sign_in(admin)
    visit("/search?q=kid")
    expect(page).to have_css(".search-results, .search-container", wait: 30)
    shot("E503_smart_search_disabled_baseline")
  end

  # ─────────────────────────────────────────────────────────────────────
  # F. Edge cases
  # ─────────────────────────────────────────────────────────────────────

  it "F601 — bell: very long username" do
    long_mod = Fabricate(:moderator, username: "the_screen_moderator_with_a_very_long_username")
    topic = seed_topic_with_post
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: admin.id,
      topic_id: topic.id,
      post_number: topic.highest_post_number,
      high_priority: true,
      data: {
        mod_note: true,
        mod_note_kind: "note",
        display_username: long_mod.username,
        excerpt: "Short note.",
        topic_title: topic.title,
        url: "#{topic.relative_url}/#{topic.highest_post_number}",
        message: "discourse_mod_categories.note_notification",
      }.to_json,
    )
    sign_in(admin)
    open_user_menu
    expect(page).to have_css(".notification.custom", wait: 30)
    shot("F601_bell_long_username")
  end

  it "F602 — shield tab: unicode in note body" do
    topic = seed_topic_with_post
    topic.custom_fields[
      "mod_topic_private_note"
    ] = "Note with emoji 🚨 and 漢字 and ñoñó for unicode coverage."
    topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
    topic.custom_fields["mod_topic_private_note_activity_at"] = Time.zone.now.iso8601
    topic.save_custom_fields(true)
    sign_in(admin)
    open_shield_tab
    expect(page).to have_css(".mod-notes-panel .mod-notes-item", wait: 30)
    shot("F602_shield_tab_unicode_note")
  end

  it "F603 — mod-note panel: very long single-line excerpt (wrap test)" do
    topic = Fabricate(:topic, category: category, title: "Panel wrap test")
    Fabricate(:post, topic: topic, user: author, raw: "OP for wrap test.")
    topic.custom_fields["mod_topic_private_note"] = "x" * 400
    topic.custom_fields["mod_topic_private_note_user_id"] = moderator.id
    topic.save_custom_fields(true)
    sign_in(moderator)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".mod-private-note", wait: 30)
    shot("F603_panel_wrap_long_excerpt")
  end

  it "F604 — bell: zero notifications (clean dropdown)" do
    sign_in(admin)
    open_user_menu
    expect(page).to have_css(".user-menu, .user-preferences-link, .quick-access-panel", wait: 30)
    shot("F604_bell_empty_state")
  end
end
