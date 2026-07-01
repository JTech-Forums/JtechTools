# frozen_string_literal: true

require "rails_helper"

# Click-through coverage: while the user is on one topic, a notification about
# a post in a DIFFERENT topic pops the toast; clicking the card opens that
# other topic at the post (exactly like clicking the row in the notifications
# dropdown) and the card goes away on click.
#
# 30 examples — 5 notification types across 6 fresh target topics each. Batch
# 1 also captures before/after screenshots (toast on the home topic, then the
# opened target) for the gallery.
#
# Each example loads the home topic fresh and publishes one crafted
# notification (retried until it lands) on the `/notification/:id` channel.
RSpec.describe "Desktop pop-up notification click-through" do
  fab!(:author) { Fabricate(:user, username: "poster_pat") }
  fab!(:recipient) { Fabricate(:user, username: "reader_rhea") }
  fab!(:category) { Fabricate(:category, name: "Flip phones") }
  fab!(:home_topic) do
    Fabricate(:topic, category: category, user: recipient, title: "The thread I am reading")
  end
  fab!(:home_op) do
    Fabricate(
      :post,
      topic: home_topic,
      user: recipient,
      raw: "Where I am when the notification arrives.",
    )
  end

  let(:user_field) { DiscoursePopupNotifications::USER_ENABLED_FIELD }
  let(:id_seq) { [800_000] }

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
      # Capture anyway rather than fail over a slow image.
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

  def wait_for_toast
    8.times do
      yield
      return if page.has_css?(".jtech-popup-toast", wait: 1.5)
    end
    expect(page).to have_css(".jtech-popup-toast", wait: 5)
  end

  def visit_home
    visit("/t/#{home_topic.slug}/#{home_topic.id}")
    expect(page).to have_css("#post_1", wait: 10)
  end

  (1..6).each do |batch|
    %i[replied mentioned quoted liked private_message].each do |type|
      it "clicking a #{type} toast opens its topic and dismisses (batch #{batch})" do
        target =
          Fabricate(:topic, category: category, user: recipient, title: "Target #{batch} #{type}")
        Fabricate(
          :post,
          topic: target,
          user: recipient,
          raw: "The opening post of the other topic.",
        )
        target_reply =
          Fabricate(
            :post,
            topic: target,
            user: author,
            raw: "The reply on the other topic that triggered the #{type} notification.",
          )

        visit_home

        wait_for_toast do
          push(
            type: type,
            topic_id: target.id,
            post_number: target_reply.post_number,
            slug: target.slug,
            fancy_title: target.fancy_title,
            data: {
              display_username: author.username,
              topic_title: target.title,
              original_post_id: target_reply.id,
            },
          )
        end

        # It pops while we are still on the home topic.
        expect(page).to have_current_path(%r{/t/[^/]+/#{home_topic.id}})
        shot("clickthrough_#{type}_01_toast_on_home") if batch == 1

        find(".jtech-popup-toast").click

        # Clicking opens the OTHER topic at the post, and the card is gone.
        expect(page).to have_current_path(%r{/t/[^/]+/#{target.id}}, wait: 10)
        expect(page).to have_css("#post_#{target_reply.post_number}", wait: 10)
        expect(page).to have_no_css(".jtech-popup-toast")
        shot("clickthrough_#{type}_02_opened_target") if batch == 1
      end
    end
  end
end
