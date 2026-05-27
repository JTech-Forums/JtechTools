# frozen_string_literal: true

require "rails_helper"

# Verifies that mod_note_unread_count derives from the same unread
# Notification rows that drive Discourse's standard bell dot — so reading a
# mod-note from the bell decrements the in-dropdown shield-tab count, and
# opening the shield tab (which marks the rows read) decrements the bell.
RSpec.describe "Mod-note unread count merge" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  before do
    SiteSetting.mod_categories_enabled = true
    Group.refresh_automatic_groups!
  end

  def create_mod_note_notification(staff_user)
    ::Notification.create!(
      notification_type: ::Notification.types[:custom],
      user_id: staff_user.id,
      high_priority: true,
      data: {
        topic_title: "Some topic",
        display_username: "modX",
        mod_note: true,
        url: "/t/1",
        message: "discourse_mod_categories.note_notification",
        title: "discourse_mod_categories.note_notification_title",
      }.to_json,
    )
  end

  def current_user_payload(actor)
    sign_in(actor)
    get "/session/current.json"
    expect(response.status).to eq(200)
    response.parsed_body["current_user"]
  end

  it "returns 0 for non-staff users" do
    create_mod_note_notification(admin) # unrelated unread on admin
    expect(current_user_payload(user)["mod_note_unread_count"]).to eq(0)
  end

  it "counts unread mod-note notifications for staff" do
    create_mod_note_notification(moderator)
    create_mod_note_notification(moderator)
    expect(current_user_payload(moderator)["mod_note_unread_count"]).to eq(2)
  end

  it "decrements the shield-tab count when a single mod-note notification is marked read from the bell" do
    n1 = create_mod_note_notification(moderator)
    create_mod_note_notification(moderator)
    expect(current_user_payload(moderator)["mod_note_unread_count"]).to eq(2)

    n1.update!(read: true)

    expect(current_user_payload(moderator)["mod_note_unread_count"]).to eq(1)
  end

  it "ignores non-mod-note custom notifications (whispers)" do
    # A whisper notification is also notification_type: :custom but carries
    # no `mod_note` marker — must not bump the shield-tab count.
    ::Notification.create!(
      notification_type: ::Notification.types[:custom],
      user_id: moderator.id,
      data: {
        topic_title: "T",
        display_username: "u",
        original_post_id: 1,
        original_post_type: 1,
      }.to_json,
    )
    expect(current_user_payload(moderator)["mod_note_unread_count"]).to eq(0)
  end

  it "drops to 0 once all mod-note notifications are read" do
    create_mod_note_notification(moderator)
    ::Notification.where(
      user_id: moderator.id,
      notification_type: ::Notification.types[:custom],
    ).update_all(read: true)

    expect(current_user_payload(moderator)["mod_note_unread_count"]).to eq(0)
  end
end
