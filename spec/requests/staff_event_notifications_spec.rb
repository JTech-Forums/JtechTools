# frozen_string_literal: true

require "rails_helper"

# Coverage for the three staff-event notification streams added on top of
# the topic mod-note pattern: a moderator deleting / approving / rejecting
# a post, a moderator adding a note to a user's profile, and a moderator
# adding a note to a flag / reviewable in the review queue. Each event
# fans out a high-priority custom notification + a live pop-up alert to
# every OTHER staff member, marked with `mod_note: true` + a specific
# `mod_note_kind` so the existing client renderer picks them up.
RSpec.describe "Staff event notifications" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_moderator, :moderator)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user) }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_notify_staff_on_post_actions = true
    SiteSetting.mod_notify_staff_on_user_notes = true
    SiteSetting.mod_notify_staff_on_flag_notes = true
    [admin, moderator, other_moderator].each { |u| u.update!(last_seen_at: Time.zone.now) }
  end

  def staff_notifications(target, kind: nil)
    scope =
      Notification.where(
        user_id: target.id,
        notification_type: Notification.types[:custom],
      )
    scope = scope.where("data LIKE ?", "%\"mod_note_kind\":\"#{kind}\"%") if kind
    scope.where("data LIKE ?", "%\"mod_note\":true%")
  end

  describe "post actions" do
    it "notifies every other staff member when a moderator deletes a post" do
      PostDestroyer.new(moderator, post).destroy

      expect(staff_notifications(admin, kind: "post_deleted").count).to eq(1)
      expect(staff_notifications(other_moderator, kind: "post_deleted").count).to eq(1)
      expect(staff_notifications(moderator, kind: "post_deleted").count).to eq(0)
    end

    it "skips the notification when the post author destroys their own post" do
      PostDestroyer.new(user, post).destroy

      expect(staff_notifications(admin, kind: "post_deleted").count).to eq(0)
    end

    it "skips when mod_notify_staff_on_post_actions is off" do
      SiteSetting.mod_notify_staff_on_post_actions = false

      PostDestroyer.new(moderator, post).destroy

      expect(staff_notifications(admin, kind: "post_deleted").count).to eq(0)
    end

    it "marks the delete notification as high priority and anchors it to the post" do
      PostDestroyer.new(moderator, post).destroy

      n = staff_notifications(admin, kind: "post_deleted").first
      expect(n.high_priority).to eq(true)
      expect(n.topic_id).to eq(topic.id)
      expect(n.post_number).to eq(post.post_number)
      data = JSON.parse(n.data)
      expect(data["url"]).to eq("#{topic.relative_url}/#{post.post_number}")
      expect(data["display_username"]).to eq(moderator.username)
    end

    it "publishes a live pop-up alert on a post delete" do
      messages =
        MessageBus
          .track_publish { PostDestroyer.new(moderator, post).destroy }
          .select { |m| m.channel.start_with?("/notification-alert/") }

      alerted = messages.map(&:channel)
      expect(alerted).to include("/notification-alert/#{admin.id}")
      expect(alerted).to include("/notification-alert/#{other_moderator.id}")
      expect(alerted).not_to include("/notification-alert/#{moderator.id}")
    end
  end

  describe "user notes", if: defined?(::DiscourseUserNotes) do
    it "notifies every other staff member when DiscourseUserNotes.add_note runs" do
      ::DiscourseUserNotes.add_note(user, "Heads up about this user.", moderator.id)

      expect(staff_notifications(admin, kind: "user_note").count).to eq(1)
      expect(staff_notifications(other_moderator, kind: "user_note").count).to eq(1)
      expect(staff_notifications(moderator, kind: "user_note").count).to eq(0)
    end

    it "links the user-note notification to the target user's notes tab" do
      ::DiscourseUserNotes.add_note(user, "Note body.", moderator.id)

      data = JSON.parse(staff_notifications(admin, kind: "user_note").first.data)
      expect(data["url"]).to eq("/u/#{user.username}/notes")
      expect(data["excerpt"]).to eq("Note body.")
      expect(data["target_username"]).to eq(user.username)
    end

    it "skips when mod_notify_staff_on_user_notes is off" do
      SiteSetting.mod_notify_staff_on_user_notes = false

      ::DiscourseUserNotes.add_note(user, "x", moderator.id)

      expect(staff_notifications(admin, kind: "user_note").count).to eq(0)
    end

    it "still returns the saved note from the wrapped add_note" do
      note = ::DiscourseUserNotes.add_note(user, "Returned shape check.", moderator.id)

      expect(note).to be_present
      expect(note[:raw] || note["raw"]).to eq("Returned shape check.")
    end
  end

  describe "flag / reviewable notes", if: defined?(ReviewableNote) do
    fab!(:reviewable) { Fabricate(:reviewable_flagged_post) }

    it "notifies every other staff member when a ReviewableNote is added" do
      ReviewableNote.create!(
        reviewable: reviewable,
        user: moderator,
        content: "Heads up, staff.",
      )

      expect(staff_notifications(admin, kind: "flag_note").count).to eq(1)
      expect(staff_notifications(other_moderator, kind: "flag_note").count).to eq(1)
      expect(staff_notifications(moderator, kind: "flag_note").count).to eq(0)
    end

    it "links the flag-note notification to the review queue entry" do
      ReviewableNote.create!(
        reviewable: reviewable,
        user: moderator,
        content: "Decision rationale.",
      )

      data = JSON.parse(staff_notifications(admin, kind: "flag_note").first.data)
      expect(data["url"]).to eq("/review/#{reviewable.id}")
      expect(data["excerpt"]).to eq("Decision rationale.")
    end

    it "skips when mod_notify_staff_on_flag_notes is off" do
      SiteSetting.mod_notify_staff_on_flag_notes = false

      ReviewableNote.create!(reviewable: reviewable, user: moderator, content: "Skip me.")

      expect(staff_notifications(admin, kind: "flag_note").count).to eq(0)
    end
  end
end
