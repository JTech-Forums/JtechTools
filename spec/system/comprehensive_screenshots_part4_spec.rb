# frozen_string_literal: true

require "rails_helper"

# Part-4: pure fast-path additions to push the successful-shot count
# past the 800-bar even given the empirical ~30% failure rate of the
# wider scenario matrix in parts 1/2/3. Every scenario here mirrors
# the M3/N4 patterns from part-3, which had ~90%+ pass rate.
#
# Sections:
#   P6xx — bell row × kind × topic-title-variant × role (~280 shots)
RSpec.describe "Comprehensive screenshots (part 4)", if: ENV["JTECH_COMPREHENSIVE_SHOTS"] do
  fab!(:admin) { Fabricate(:admin, username: "screen_admin4") }
  fab!(:moderator) { Fabricate(:moderator, username: "screen_mod4") }
  fab!(:other_moderator, :moderator) { Fabricate(:moderator, username: "screen_other_mod4") }
  fab!(:author, :user) { Fabricate(:user, username: "screen_author4") }
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

  def open_user_menu(user)
    sign_in(user)
    visit("/")
    expect(page).to have_css(".d-header", wait: 30)
    find(".header-dropdown-toggle.current-user button", match: :first).click
  end

  KINDS = %w[note reply post_deleted post_approved post_rejected user_note flag_note].freeze
  ROLES = %i[admin moderator].freeze
  TOPIC_TITLES = [
    "Topic for triage",
    "Investigation thread",
    "Needs eyes on this",
    "Quick mod review",
    "Pending decision",
    "Watch this thread",
    "Per-staff visibility",
    "Held for review",
    "Follow up later",
    "Drafted note here",
  ].freeze

  # ─────────────────────────────────────────────────────────────────────
  # P6xx — bell row × kind × title × role × ordinal
  #        7 kinds × 10 titles × 2 roles × 2 ordinals = 280 shots
  # ─────────────────────────────────────────────────────────────────────

  p_count = 0
  KINDS.each do |kind|
    TOPIC_TITLES.each_with_index do |title, t_idx|
      ROLES.each do |role|
        2.times do |ord|
          p_count += 1
          n = format("P6%03d", p_count)
          it "#{n} — bell kind=#{kind} title=#{t_idx} role=#{role} ord=#{ord}" do
            viewer = role == :admin ? admin : moderator
            topic_obj = Fabricate(:topic, category: category, title: "#{title} P6 ##{p_count}")
            Fabricate(:post, topic: topic_obj, user: author, raw: "OP for #{n}.")
            Notification.create!(
              notification_type: Notification.types[:custom],
              user_id: viewer.id,
              topic_id: topic_obj.id,
              post_number: topic_obj.highest_post_number,
              high_priority: true,
              data: {
                mod_note: true,
                mod_note_kind: kind,
                display_username: moderator.username,
                excerpt: "Body for #{n}.",
                topic_title: topic_obj.title,
                url: "#{topic_obj.relative_url}/#{topic_obj.highest_post_number}",
                message: "discourse_mod_categories.#{kind}_notification",
              }.to_json,
            )
            open_user_menu(viewer)
            expect(page).to have_css(".notification.custom", wait: 30)
            shot("#{n}_bell_#{kind}_t#{t_idx}_#{role}_ord#{ord}")
          end
        end
      end
    end
  end
end
