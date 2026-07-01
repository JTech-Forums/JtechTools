# frozen_string_literal: true

require "rails_helper"

# Screenshot gallery for STACKING — when more than one notification arrives,
# the cards stack one below another (newest on top, just below the header
# search), up to 3 at once; a 4th drops the oldest (bottom) card so the newest
# can take its place. 25 shots across single/double/triple stacks, type mixes,
# content shapes, and the overflow-replaces-oldest behavior.
#
# Reliability: after a fresh page load the browser's MessageBus poll can take
# a moment to subscribe, so each example first "primes" the channel (publish +
# wait + dismiss) and then builds the stack with one publish per card, waiting
# for the exact card count each step.
#
# Screenshots land in tmp/capybara/ and are published as the CI artifact.
RSpec.describe "Desktop pop-up notification stacking screenshots" do
  fab!(:author) { Fabricate(:user, username: "poster_pat", name: "Pat Poster") }
  fab!(:author2) { Fabricate(:user, username: "quinn_quill", name: "Quinn Quill") }
  fab!(:recipient) { Fabricate(:user, username: "reader_rhea") }
  fab!(:category) { Fabricate(:category, name: "Flip phones") }
  fab!(:topic) do
    Fabricate(
      :topic,
      category: category,
      user: recipient,
      title: "Might be the next Qin but better",
    )
  end
  fab!(:op) do
    Fabricate(:post, topic: topic, user: recipient, raw: "What do you all think of this phone?")
  end
  fab!(:reply_post) do
    Fabricate(
      :post,
      topic: topic,
      user: author,
      raw:
        "Excellent screen quality. Supports 4g volte in Israel with excellent cellular reception.",
    )
  end
  fab!(:reply_post2) do
    Fabricate(:post, topic: topic, user: author2, raw: "Battery life is genuinely impressive too.")
  end
  fab!(:long_reply) do
    Fabricate(
      :post,
      topic: topic,
      user: author,
      raw:
        "Honestly this might be the best budget option out there right now — the build feels " \
          "premium, the screen is bright even outdoors, and the battery lasts a day and a half.",
    )
  end
  fab!(:long_topic) do
    Fabricate(
      :topic,
      category: category,
      user: recipient,
      title:
        "A remarkably and unnecessarily long topic title that should be truncated with an " \
          "ellipsis inside the pop-up card so it never wraps onto a second line",
    )
  end
  fab!(:long_topic_reply) do
    Fabricate(:post, topic: long_topic, user: author2, raw: "See the specs I linked above.")
  end

  let(:user_field) { DiscoursePopupNotifications::USER_ENABLED_FIELD }
  let(:id_seq) { [700_000] }

  # Gallery spec: generates screenshots in the Feature Screenshots workflow
  # (which sets this env). Skipped in the main parallel system_tests run so it
  # does not weigh that job down.
  before { skip("screenshot-gallery only") unless ENV["JTECH_SCREENSHOT_GALLERY"] }

  before do
    SiteSetting.popup_notifications_enabled = true
    SiteSetting.popup_notifications_timeout_seconds = 300
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    recipient.custom_fields[user_field] = true
    recipient.save_custom_fields(true)
    sign_in(recipient)
  end

  def shot(name)
    begin
      Timeout.timeout(8) do
        sleep 0.1 until page.evaluate_script("Array.from(document.images).every((i) => i.complete)")
      end
    rescue Timeout::Error
      # Capture anyway rather than fail over a slow avatar image.
    end
    page.save_screenshot("popup_notifications_#{name}.png")
  end

  def push(type:, data:, topic_id: nil, post_number: nil, fancy_title: nil, slug: nil)
    id_seq[0] += 1
    MessageBus.publish(
      "/notification/#{recipient.id}",
      {
        unread_notifications: 1,
        all_unread_notifications_count: 1,
        last_notification: {
          notification: {
            id: id_seq[0],
            user_id: recipient.id,
            notification_type: Notification.types[type],
            read: false,
            created_at: Time.zone.now.iso8601,
            post_number: post_number,
            topic_id: topic_id,
            fancy_title: fancy_title,
            slug: slug,
            data: data,
          },
        },
      },
      user_ids: [recipient.id],
    )
  end

  # Spec builders for the common notification shapes.
  def enriched(type, post: reply_post, into: topic)
    {
      type: type,
      topic_id: into.id,
      post_number: post.post_number,
      slug: into.slug,
      fancy_title: into.fancy_title,
      data: {
        display_username: post.user.username,
        topic_title: into.title,
        original_post_id: post.id,
      },
    }
  end

  def whisper(post: reply_post, into: topic)
    enriched(:custom, post: post, into: into).tap { |h| h[:data][:mod_whisper] = true }
  end

  def mod_note(kind, username: "mod_mia", excerpt:, title: nil)
    data = {
      mod_note: true,
      mod_note_kind: kind,
      display_username: username,
      excerpt: excerpt,
      url: "/review",
    }
    data[:topic_title] = title if title
    { type: :custom, data: data }
  end

  def fallback(username: "system_sam", title:, excerpt:)
    {
      type: :custom,
      data: {
        display_username: username,
        topic_title: title,
        excerpt: excerpt,
        url: "/u/#{recipient.username}/notifications",
      },
    }
  end

  def visit_topic
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#post_1", wait: 10)
  end

  # Ensure the browser's MessageBus subscription is live, then clear the stack.
  def prime
    8.times do
      push(**enriched(:replied))
      break if page.has_css?(".jtech-popup-toast", wait: 1.5)
    end
    expect(page).to have_css(".jtech-popup-toast", wait: 5)
    find("#post_1 .cooked").click
    expect(page).to have_no_css(".jtech-popup-toast")
  end

  # Build a stack of up to 3 cards, one publish per card, and screenshot it.
  def stack_shot(name, *specs)
    visit_topic
    prime
    specs.each_with_index do |spec, index|
      push(**spec)
      expect(page).to have_css(".jtech-popup-toast", count: index + 1, wait: 10)
    end
    shot(name)
  end

  # Push more than the cap; the stack settles at 3 with `top_icon` at the top.
  def overflow_shot(name, specs, top_icon:)
    visit_topic
    prime
    specs.each { |spec| push(**spec) }
    expect(page).to have_css(".jtech-popup-toast", count: 3, wait: 10)
    expect(page).to have_css(".jtech-popup-toast:first-child #{top_icon}", wait: 10)
    shot(name)
  end

  it "single and double stacks (01–09)" do
    stack_shot("stack_01_single_reply", enriched(:replied))
    stack_shot("stack_02_reply_like", enriched(:replied), enriched(:liked))
    stack_shot("stack_03_reply_mention", enriched(:replied), enriched(:mentioned))
    stack_shot("stack_04_reply_quote", enriched(:replied), enriched(:quoted))
    stack_shot("stack_05_pm_reply", enriched(:private_message), enriched(:replied))
    stack_shot("stack_06_whisper_reply", whisper, enriched(:replied))
    stack_shot(
      "stack_07_flag_pending",
      mod_note("flag_note", excerpt: "Flagged as spam — please review."),
      mod_note("post_approved", title: topic.title, excerpt: "Approved a queued reply."),
    )
    stack_shot("stack_08_badge_reply", enriched(:granted_badge), enriched(:replied))
    stack_shot("stack_09_edited_linked", enriched(:edited), enriched(:linked))
  end

  it "triple stacks by type mix (10–17)" do
    stack_shot(
      "stack_10_reply_like_mention",
      enriched(:replied),
      enriched(:liked),
      enriched(:mentioned),
    )
    stack_shot(
      "stack_11_reply_quote_pm",
      enriched(:replied),
      enriched(:quoted),
      enriched(:private_message),
    )
    stack_shot(
      "stack_12_whisper_flag_pending",
      whisper,
      mod_note("flag_note", excerpt: "Flagged as off-topic."),
      mod_note("post_approved", title: topic.title, excerpt: "Approved a queued reply."),
    )
    stack_shot(
      "stack_13_like_x3",
      enriched(:liked),
      enriched(:liked, post: reply_post2),
      enriched(:liked),
    )
    stack_shot(
      "stack_14_mention_quote_reply",
      enriched(:mentioned),
      enriched(:quoted),
      enriched(:replied),
    )
    stack_shot("stack_15_pm_whisper_reply", enriched(:private_message), whisper, enriched(:replied))
    stack_shot(
      "stack_16_reply_flag_like",
      enriched(:replied),
      mod_note("flag_note", excerpt: "A new flag needs attention."),
      enriched(:liked),
    )
    stack_shot(
      "stack_17_fallback_reply_whisper",
      fallback(
        title: "Scheduled maintenance",
        excerpt: "The forum will be briefly offline at 2am.",
      ),
      enriched(:replied),
      whisper,
    )
  end

  it "content shapes and more mixes in a stack (18–23)" do
    stack_shot(
      "stack_18_longtitle_reply_like",
      enriched(:replied, post: long_topic_reply, into: long_topic),
      enriched(:replied),
      enriched(:liked),
    )
    stack_shot(
      "stack_19_longmessage_like_mention",
      enriched(:replied, post: long_reply),
      enriched(:liked),
      enriched(:mentioned),
    )
    stack_shot(
      "stack_20_badge_pm_reply",
      enriched(:granted_badge),
      enriched(:private_message),
      enriched(:replied),
    )
    stack_shot(
      "stack_21_edited_linked_quote",
      enriched(:edited),
      enriched(:linked),
      enriched(:quoted),
    )
    stack_shot(
      "stack_22_flag_pending_whisper",
      mod_note("flag_note", excerpt: "Flag raised on a reply."),
      mod_note("post_rejected", title: topic.title, excerpt: "Rejected a queued reply."),
      whisper,
    )
    stack_shot(
      "stack_23_three_replies_mixed",
      enriched(:replied),
      enriched(:replied, post: reply_post2),
      enriched(:replied, post: long_topic_reply, into: long_topic),
    )
  end

  it "overflow — a 4th notification replaces the oldest (24–25)" do
    overflow_shot(
      "stack_24_overflow_engagement",
      [enriched(:replied), enriched(:liked), enriched(:mentioned), whisper],
      top_icon: ".d-icon-eye",
    )
    overflow_shot(
      "stack_25_overflow_staff",
      [
        whisper,
        mod_note("flag_note", excerpt: "Flagged for review."),
        mod_note("post_approved", title: topic.title, excerpt: "Approved a queued reply."),
        enriched(:liked),
      ],
      top_icon: ".d-icon-heart",
    )
  end
end
