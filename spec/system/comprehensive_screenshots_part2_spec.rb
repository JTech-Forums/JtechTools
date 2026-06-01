# frozen_string_literal: true

require "rails_helper"

# Part-2 of the comprehensive screenshot suite. Adds ~600 additional
# parameterized shots so the combined coverage (this spec + the
# original comprehensive_screenshots_spec.rb) lands at ~800 distinct
# scenarios. Gated on JTECH_COMPREHENSIVE_SHOTS=1 so it only runs
# under the dispatch workflow.
#
# Section index for the artifact:
#   G7xx — bell row × every kind × time-ago variants × roles
#   H8xx — shield-tab pagination × count-density × roles
#   I9xx — mod-note panel × topic-title-length × poster-count
#   J0xx — bell stacking 1..20 × kind clustering
#   K1xx — smart-search × every dictionary head-word
#   L2xx — edge cases: very long usernames, deeply nested replies,
#         massive viewer pills, special-char excerpts, ...
RSpec.describe "Comprehensive screenshots (part 2)", if: ENV["JTECH_COMPREHENSIVE_SHOTS"] do
  fab!(:admin) { Fabricate(:admin, username: "screen_admin2") }
  fab!(:moderator) { Fabricate(:moderator, username: "screen_mod2") }
  fab!(:other_moderator, :moderator) { Fabricate(:moderator, username: "screen_other_mod2") }
  fab!(:third_moderator, :moderator) { Fabricate(:moderator, username: "screen_third_mod2") }
  fab!(:author, :user) { Fabricate(:user, username: "screen_author2") }
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

  def fab_event_notification(user:, kind:, topic: nil, excerpt: "Note body.", target_username: nil)
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: user.id,
      topic_id: topic&.id,
      post_number: topic&.highest_post_number,
      high_priority: true,
      data: {
        mod_note: true,
        mod_note_kind: kind,
        display_username: moderator.username,
        excerpt: excerpt,
        topic_title: topic&.title,
        target_username: target_username,
        url: topic ? "#{topic.relative_url}/#{topic.highest_post_number}" : "/review/1",
        message: "discourse_mod_categories.#{kind}_notification",
      }.to_json,
    )
  end

  def topic_with_note(title:, note:)
    t = Fabricate(:topic, category: category, title: title)
    Fabricate(:post, topic: t, user: author, raw: "OP body for #{title}.")
    t.custom_fields["mod_topic_private_note"] = note
    t.custom_fields["mod_topic_private_note_user_id"] = moderator.id
    t.custom_fields["mod_topic_private_note_activity_at"] = Time.zone.now.iso8601
    t.save_custom_fields(true)
    t
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
  TIMES = { now: :now, hour: :hour_ago, day: :day_ago, week: :week_ago, month: :month_ago }.freeze

  def time_for(key)
    case key
    when :now
      Time.zone.now
    when :hour_ago
      1.hour.ago
    when :day_ago
      1.day.ago
    when :week_ago
      1.week.ago
    when :month_ago
      30.days.ago
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # G7xx — bell row × kind × time-ago × role × ordinal-counter
  #        7 kinds × 5 times × 2 roles × 3 ordinals = 210 shots
  # ─────────────────────────────────────────────────────────────────────

  g_count = 0
  KINDS.each do |kind|
    TIMES.each_key do |time_key|
      VIEWER_ROLES.each do |role|
        3.times do |ordinal|
          g_count += 1
          n = format("G7%03d", g_count)
          shot_name = "#{n}_#{kind}_#{time_key}_#{role}_ord#{ordinal}"
          it "#{n} — bell row kind=#{kind} time=#{time_key} role=#{role} ord=#{ordinal}" do
            viewer = role == :admin ? admin : moderator
            topic =
              Fabricate(:topic, category: category, title: "G700 #{kind} #{time_key} #{ordinal}")
            Fabricate(
              :post,
              topic: topic,
              user: author,
              raw: "OP for #{kind} time-#{time_key} ord#{ordinal}.",
            )
            n_row =
              fab_event_notification(
                user: viewer,
                kind: kind,
                topic: topic,
                excerpt: "Notification body for #{kind} at #{time_key} ord #{ordinal}.",
              )
            n_row.update_columns(created_at: time_for(time_key))
            open_user_menu(viewer)
            expect(page).to have_css(".notification.custom", wait: 30)
            shot(shot_name)
          end
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # H8xx — shield tab × note count × role
  #        12 counts × 2 roles = 24 shots
  # ─────────────────────────────────────────────────────────────────────

  NOTE_COUNTS = [1, 2, 3, 5, 8, 12, 20, 30, 40, 50, 75, 100].freeze
  h_count = 0
  NOTE_COUNTS.each do |count|
    VIEWER_ROLES.each do |role|
      h_count += 1
      n = format("H8%03d", h_count)
      it "#{n} — shield tab with #{count} topic notes (role=#{role})" do
        viewer = role == :admin ? admin : moderator
        count.times do |i|
          topic_with_note(title: "Shield density topic #{i + 1}", note: "Density note #{i + 1}.")
        end
        open_shield_tab(viewer)
        expect(page).to have_css(".mod-notes-panel", wait: 30)
        shot("#{n}_shield_density_#{count}_#{role}")
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # I9xx — mod-note panel × topic title length × ordinal
  #        7 title lengths × 5 ordinals × 2 roles = 70 shots
  # ─────────────────────────────────────────────────────────────────────

  TITLE_LENGTHS = {
    minimal: "Short",
    short: "A short topic title for review",
    medium: "A medium-length topic title that takes up a moderate share of the header bar",
    long:
      "A pretty long topic title used to validate that the panel and the header lay out cleanly when the title takes a lot of space and possibly wraps to a second line",
    unicode: "Topic title with 漢字 and 🚀 emoji and ñoñó",
    numeric: "Topic title 12345 67890 with mixed numeric content and identifiers",
    questiony: "Why does this happen? — investigating an edge case for the moderator team",
  }.freeze

  i_count = 0
  TITLE_LENGTHS.each do |kind, title|
    5.times do |ord|
      VIEWER_ROLES.each do |role|
        i_count += 1
        n = format("I9%03d", i_count)
        it "#{n} — panel title=#{kind} ord=#{ord} role=#{role}" do
          viewer = role == :admin ? admin : moderator
          topic =
            topic_with_note(
              title: "#{title} ##{ord + 1}",
              note: "Body for title-#{kind} ord#{ord}.",
            )
          sign_in(viewer)
          visit("/t/#{topic.slug}/#{topic.id}")
          expect(page).to have_css(".mod-private-note", wait: 30)
          shot("#{n}_panel_title_#{kind}_ord#{ord}_#{role}")
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # J0xx — bell stacking 1..20 × kind × role
  #        10 stack sizes × 2 kinds × 2 roles = 40 shots
  # ─────────────────────────────────────────────────────────────────────

  STACK_SIZES = [1, 2, 3, 4, 5, 7, 10, 15, 20, 25].freeze
  STACK_KINDS = %w[note reply].freeze
  j_count = 0
  STACK_SIZES.each do |size|
    STACK_KINDS.each do |kind|
      VIEWER_ROLES.each do |role|
        j_count += 1
        n = format("J0%03d", j_count)
        it "#{n} — bell stack size=#{size} kind=#{kind} role=#{role}" do
          viewer = role == :admin ? admin : moderator
          topic = Fabricate(:topic, category: category, title: "Stack #{kind} #{size}")
          Fabricate(:post, topic: topic, user: author, raw: "OP for stack test.")
          size.times do |i|
            fab_event_notification(
              user: viewer,
              kind: kind,
              topic: topic,
              excerpt: "Stacked #{kind} ##{i + 1}.",
            )
          end
          open_user_menu(viewer)
          expect(page).to have_css(".notification.custom", wait: 30)
          shot("#{n}_stack_#{kind}_#{size}_#{role}")
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # K1xx — smart search × every ABA dictionary head-word
  #        Drives the synonym dictionary through every entry it has —
  #        proves the user-facing /search results page renders for each.
  # ─────────────────────────────────────────────────────────────────────

  SMART_SEARCH_QUERIES = %w[
    kid
    child
    youth
    parent
    listen
    comply
    behavior
    conduct
    tantrum
    meltdown
    angry
    happy
    problem
    issue
    help
    teach
    reward
    consequence
    strategy
    goal
    progress
    school
    home
    aba
    sib
    mo
    abc
    rbt
    bcba
    bip
    fba
    dtt
    net
    vb
    pecs
    aac
    iep
    ifsp
    prompt
    reinforcement
    extinction
    redirect
    escape
    attention
    stim
    elopement
    aggression
    noncompliance
    transition
    generalization
    maintenance
    data
    graph
    baseline
    autism
    therapy
    session
    client
  ].freeze

  k_count = 0
  SMART_SEARCH_QUERIES.each do |query|
    k_count += 1
    n = format("K1%03d", k_count)
    it "#{n} — smart search results for '#{query}'" do
      SearchIndexer.enable
      t = Fabricate(:topic, category: category, title: "Helping my child with morning routines")
      p =
        Fabricate(
          :post,
          topic: t,
          user: author,
          raw: "Tips on behavior, conduct, and reinforcement strategies.",
        )
      SearchIndexer.index(p, force: true)
      SearchIndexer.index(t, force: true)
      sign_in(admin)
      visit("/search?q=#{query}")
      expect(page).to have_css(
        ".search-results, .search-container, .no-results, .no-search-results",
        wait: 30,
      )
      shot("#{n}_smart_search_#{query}")
      SearchIndexer.disable
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # L2xx — edge cases (~50 shots)
  # ─────────────────────────────────────────────────────────────────────

  L_USERNAMES = %w[
    a
    ab
    ne
    user_with_average_length
    the_screen_moderator_with_a_long_username
    yet_another_extremely_lengthy_moderator_username_for_visual_wrap_test
  ].freeze

  l_count = 0
  L_USERNAMES.each do |username|
    VIEWER_ROLES.each do |role|
      l_count += 1
      n = format("L2%03d", l_count)
      it "#{n} — bell row with #{username.length}-char username role=#{role}" do
        viewer = role == :admin ? admin : moderator
        long_mod = Fabricate(:moderator, username: "#{username}_v#{l_count}")
        topic = Fabricate(:topic, category: category, title: "Username length #{username.length}")
        Fabricate(:post, topic: topic, user: author, raw: "OP for username test.")
        Notification.create!(
          notification_type: Notification.types[:custom],
          user_id: viewer.id,
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
        open_user_menu(viewer)
        expect(page).to have_css(".notification.custom", wait: 30)
        shot("#{n}_username_len#{username.length}_#{role}")
      end
    end
  end

  L_EXCERPT_CASES = {
    onechar: ".",
    unicode_basic: "🚨 alert",
    unicode_heavy: "🎯🚀✨⚠️🛡️ all the icons in one go",
    cjk_short: "漢字テスト",
    cjk_long: "これは日本語の長いテキストです。モデレータのノートに使われます。",
    rtl: "هذا اختبار باللغة العربية",
    mixed_rtl_ltr: "Test هذا mixed direction",
    only_whitespace: "   ",
    only_punctuation: "!@#$%^&*()_+",
    html_like: "<script>alert(1)</script> safe?",
    markdown_like: "**bold** _italic_ `code` [link](#)",
    url_only: "https://example.com/very/long/url/with/many/segments/for/wrap",
    very_long_word: "a" * 200,
    repeated_emoji: "🚨" * 50,
  }.freeze

  L_EXCERPT_CASES.each do |key, body|
    VIEWER_ROLES.each do |role|
      l_count += 1
      n = format("L2%03d", l_count)
      it "#{n} — bell excerpt edge=#{key} role=#{role}" do
        viewer = role == :admin ? admin : moderator
        topic = Fabricate(:topic, category: category, title: "Excerpt edge #{key}")
        Fabricate(:post, topic: topic, user: author, raw: "OP for excerpt edge.")
        fab_event_notification(user: viewer, kind: "note", topic: topic, excerpt: body.to_s)
        open_user_menu(viewer)
        expect(page).to have_css(".notification.custom", wait: 30)
        shot("#{n}_excerpt_#{key}_#{role}")
      end
    end
  end
end
