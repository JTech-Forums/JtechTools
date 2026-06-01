# frozen_string_literal: true

require "rails_helper"

# Verifies the POST /discourse-mod-categories/topic/:topic_id/notifications/seen
# endpoint marks the current user's custom mod-note and mod-whisper
# notifications as read for that topic — Discourse's built-in
# auto-mark-read skips `Notification.types[:custom]`, so without this
# endpoint plugin notifications would stay unread in the bell after the
# user opens the topic.
RSpec.describe "Mark topic notifications seen" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:other_topic, :topic)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: user) }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
  end

  def make_notification(user:, topic:, data_marker:)
    Notification.create!(
      notification_type: Notification.types[:custom],
      user_id: user.id,
      topic_id: topic.id,
      post_number: topic.highest_post_number,
      data: { topic_title: topic.title }.merge(data_marker).to_json,
    )
  end

  it "marks mod-note notifications for the topic as read" do
    notif = make_notification(user: admin, topic: topic, data_marker: { mod_note: true })
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{topic.id}/notifications/seen.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["marked"]).to eq(1)
    expect(notif.reload.read).to eq(true)
  end

  it "marks mod-whisper notifications for the topic as read" do
    notif = make_notification(user: admin, topic: topic, data_marker: { mod_whisper: true })
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{topic.id}/notifications/seen.json"

    expect(notif.reload.read).to eq(true)
  end

  it "marks legacy whisper_notification rows by the i18n message key" do
    notif =
      make_notification(
        user: admin,
        topic: topic,
        data_marker: {
          message: "discourse_mod_categories.whisper.whisper_notification",
        },
      )
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{topic.id}/notifications/seen.json"

    expect(notif.reload.read).to eq(true)
  end

  it "does not touch notifications for other topics" do
    target_notif = make_notification(user: admin, topic: topic, data_marker: { mod_note: true })
    untouched = make_notification(user: admin, topic: other_topic, data_marker: { mod_note: true })
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{topic.id}/notifications/seen.json"

    expect(target_notif.reload.read).to eq(true)
    expect(untouched.reload.read).to eq(false)
  end

  it "does not touch other users' notifications for the same topic" do
    target_notif = make_notification(user: admin, topic: topic, data_marker: { mod_note: true })
    other_user_notif =
      make_notification(user: moderator, topic: topic, data_marker: { mod_note: true })
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{topic.id}/notifications/seen.json"

    expect(target_notif.reload.read).to eq(true)
    expect(other_user_notif.reload.read).to eq(false)
  end

  it "does not touch unrelated custom notifications attached to the same topic" do
    target_notif = make_notification(user: admin, topic: topic, data_marker: { mod_note: true })
    third_party =
      make_notification(user: admin, topic: topic, data_marker: { some_other_plugin: true })
    sign_in(admin)

    post "/discourse-mod-categories/topic/#{topic.id}/notifications/seen.json"

    expect(target_notif.reload.read).to eq(true)
    expect(third_party.reload.read).to eq(false)
  end

  it "returns 404 for a non-existent topic" do
    sign_in(admin)
    post "/discourse-mod-categories/topic/9999999/notifications/seen.json"
    expect(response.status).to eq(404)
  end

  it "requires login" do
    post "/discourse-mod-categories/topic/#{topic.id}/notifications/seen.json"
    expect(response.status).to eq(403).or eq(404)
  end
end
