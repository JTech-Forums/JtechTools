# frozen_string_literal: true

require "rails_helper"

# Integration-style coverage for the five staff-event notification streams.
# Where staff_event_notifications_spec.rb hits the model layer directly
# (PostDestroyer.new(...).destroy, ReviewableNote.create!, …), this spec
# drives the SAME fan-outs through the realistic HTTP endpoints a staff
# member actually uses in the UI — POST /post_actions, DELETE /posts/:id,
# PUT /review/:id/perform/:action, POST /review/:id/notes. The point is
# to catch integration-layer regressions that bypass the model specs:
# controller authorization, missing serializer fields, schema drift in
# the review queue payload, etc.
#
# Each describe block also includes an error-injection test that forces
# the fan-out's dependencies into a bad state and asserts the user's
# core action STILL succeeds — the staff-notify side effect must be
# best-effort and never block the underlying moderator action.
RSpec.describe "Staff event notifications (integration)" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_moderator, :moderator)
  fab!(:flagger_moderator, :moderator)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:tl0_user) { Fabricate(:newuser, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category, user: user) }
  # NB: do NOT name this fab `:post` — the request-spec helper for HTTP
  # POST has the same name, and RSpec resolves `post "/path", params: {}`
  # to the let_it_be accessor, which then raises ArgumentError because
  # the lazy accessor takes 0 args. `target_post` is the unambiguous name.
  fab!(:target_post) { Fabricate(:post, topic: topic, user: user) }

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_notify_staff_on_post_actions = true
    SiteSetting.mod_notify_staff_on_user_notes = true
    SiteSetting.mod_notify_staff_on_flag_notes = true
    [admin, moderator, other_moderator, flagger_moderator].each do |u|
      u.update!(last_seen_at: Time.zone.now)
    end
  end

  def staff_notifications(target, kind: nil)
    scope = Notification.where(user_id: target.id, notification_type: Notification.types[:custom])
    scope = scope.where("data LIKE ?", "%\"mod_note_kind\":\"#{kind}\"%") if kind
    scope.where("data LIKE ?", "%\"mod_note\":true%")
  end

  describe "flag lifecycle via /post_actions and /review/:id/perform" do
    it "flags a post via POST /post_actions.json and resolves it via PUT /review/:id/perform" do
      sign_in(flagger_moderator)

      post "/post_actions.json",
           params: {
             id: target_post.id,
             post_action_type_id: PostActionType.types[:spam],
           }
      expect(response.status).to be_between(200, 299)

      reviewable = ReviewableFlaggedPost.find_by(target: target_post)
      expect(reviewable).to be_present

      sign_in(moderator)
      put "/review/#{reviewable.id}/perform/agree_and_keep.json",
          params: {
            version: reviewable.reload.version,
          }
      expect(response.status).to be_between(200, 299)
    end

    it "lets a DIFFERENT mod add a ReviewableNote via /review/:id/notes after a flag is filed" do
      sign_in(flagger_moderator)
      post "/post_actions.json",
           params: {
             id: target_post.id,
             post_action_type_id: PostActionType.types[:spam],
           }
      reviewable = ReviewableFlaggedPost.find_by(target: target_post)
      expect(reviewable).to be_present

      sign_in(other_moderator)
      expect {
        post "/review/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "Looking into this now.",
               },
             }
      }.to change { staff_notifications(admin, kind: "flag_note").count }.by(1)
      expect(response.status).to be_between(200, 299)

      # The mod who WROTE the note does not notify themselves.
      expect(staff_notifications(other_moderator, kind: "flag_note").count).to eq(0)
      # Other staff get notified.
      expect(staff_notifications(moderator, kind: "flag_note").count).to eq(1)

      data = JSON.parse(staff_notifications(admin, kind: "flag_note").first.data)
      expect(data["url"]).to eq("/review/#{reviewable.id}")
      expect(data["excerpt"]).to eq("Looking into this now.")
      expect(data["display_username"]).to eq(other_moderator.username)
    end

    it "still completes the flag request when the staff fan-out raises mid-flight" do
      sign_in(flagger_moderator)

      # Force StaffNotifier.fan_out to blow up. The user's core action — filing
      # the flag — must still succeed; the notify side effect is best-effort.
      allow(DiscourseModCategories::StaffNotifier).to receive(:fan_out).and_raise(
        StandardError,
        "induced failure",
      )

      expect {
        post "/post_actions.json",
             params: {
               id: target_post.id,
               post_action_type_id: PostActionType.types[:spam],
             }
      }.to change { ReviewableFlaggedPost.where(target: target_post).count }.by(1)
      expect(response.status).to be_between(200, 299)
    end
  end

  describe "post deletion via DELETE /posts/:id.json" do
    fab!(:second_post) { Fabricate(:post, topic: topic, user: user, raw: "Delete me please.") }

    it "fans out a post_deleted notification with the correct excerpt and url" do
      sign_in(moderator)

      expect {
        delete "/posts/#{second_post.id}.json"
      }.to change { staff_notifications(admin, kind: "post_deleted").count }.by(1)
      expect(response.status).to be_between(200, 299)

      notification = staff_notifications(admin, kind: "post_deleted").last
      expect(notification.topic_id).to eq(topic.id)
      expect(notification.post_number).to eq(second_post.post_number)
      expect(notification.high_priority).to eq(true)

      data = JSON.parse(notification.data)
      expect(data["display_username"]).to eq(moderator.username)
      expect(data["url"]).to eq("#{topic.relative_url}/#{second_post.post_number}")
      expect(data["excerpt"]).to include("Delete me please.")

      # The acting moderator gets nothing; other staff do.
      expect(staff_notifications(moderator, kind: "post_deleted").count).to eq(0)
      expect(staff_notifications(other_moderator, kind: "post_deleted").count).to eq(1)
    end

    it "still deletes the post when the staff fan-out raises mid-flight" do
      sign_in(moderator)

      allow(DiscourseModCategories::StaffNotifier).to receive(:fan_out).and_raise(
        StandardError,
        "induced failure",
      )

      delete "/posts/#{second_post.id}.json"
      expect(response.status).to be_between(200, 299)
      expect(second_post.reload.deleted_at).to be_present
    end
  end

  describe "queued-post approve / reject via /review/:id/perform" do
    fab!(:reviewable_queued) do
      Fabricate(
        :reviewable_queued_post,
        target_created_by: tl0_user,
        topic: topic,
        payload: {
          raw: "This is a queued reply body long enough to validate.",
        },
      )
    end

    it "fans out a post_approved notification when a moderator approves via /review/:id/perform/approve_post" do
      sign_in(moderator)

      expect {
        put "/review/#{reviewable_queued.id}/perform/approve_post.json",
            params: {
              version: reviewable_queued.version,
            }
      }.to change { staff_notifications(admin, kind: "post_approved").count }.by(1)
      expect(response.status).to be_between(200, 299)

      # The approving moderator does NOT notify themselves.
      expect(staff_notifications(moderator, kind: "post_approved").count).to eq(0)
      # Other staff do get notified.
      expect(staff_notifications(other_moderator, kind: "post_approved").count).to eq(1)

      data = JSON.parse(staff_notifications(admin, kind: "post_approved").last.data)
      expect(data["display_username"]).to eq(moderator.username)
    end

    it "fans out a post_rejected notification when a moderator rejects via /review/:id/perform/reject_post" do
      sign_in(moderator)

      expect {
        put "/review/#{reviewable_queued.id}/perform/reject_post.json",
            params: {
              version: reviewable_queued.version,
            }
      }.to change { staff_notifications(admin, kind: "post_rejected").count }.by(1)
      expect(response.status).to be_between(200, 299)

      data = JSON.parse(staff_notifications(admin, kind: "post_rejected").last.data)
      expect(data["url"]).to eq("/review/#{reviewable_queued.id}")
      # The payload-derived excerpt should come through.
      expect(data["excerpt"]).to include("queued reply body")
      expect(staff_notifications(moderator, kind: "post_rejected").count).to eq(0)
    end

    it "still approves the queued post when the staff fan-out raises mid-flight" do
      sign_in(moderator)

      allow(DiscourseModCategories::StaffNotifier).to receive(:fan_out).and_raise(
        StandardError,
        "induced failure",
      )

      put "/review/#{reviewable_queued.id}/perform/approve_post.json",
          params: {
            version: reviewable_queued.version,
          }
      expect(response.status).to be_between(200, 299)
      expect(reviewable_queued.reload.status).not_to eq(Reviewable.statuses[:pending])
    end
  end

  describe "user notes added via DiscourseUserNotes", if: defined?(::DiscourseUserNotes) do
    it "fans out a user_note notification when a mod adds one through the wrapped add_note" do
      expect {
        ::DiscourseUserNotes.add_note(user, "Integration-pathway note body.", moderator.id)
      }.to change { staff_notifications(admin, kind: "user_note").count }.by(1)

      data = JSON.parse(staff_notifications(admin, kind: "user_note").last.data)
      expect(data["url"]).to eq("/u/#{user.username}/notes")
      expect(data["target_username"]).to eq(user.username)
      expect(data["display_username"]).to eq(moderator.username)
      expect(staff_notifications(moderator, kind: "user_note").count).to eq(0)
    end

    it "still saves the user note when the staff fan-out raises mid-flight" do
      # The add_note wrapper already has rescue StandardError, so the underlying
      # note write must complete and the returned hash must be present.
      allow(DiscourseModCategories::StaffNotifier).to receive(:fan_out).and_raise(
        StandardError,
        "induced failure",
      )

      note = ::DiscourseUserNotes.add_note(user, "Survive the fan-out crash.", moderator.id)
      expect(note).to be_present
      expect(note[:raw] || note["raw"]).to eq("Survive the fan-out crash.")
    end
  end

  describe "ReviewableNote added via POST /review/:id/notes.json" do
    fab!(:reviewable, :reviewable_flagged_post)

    it "fans out a flag_note notification through the controller endpoint" do
      sign_in(moderator)

      expect {
        post "/review/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "Controller-path note body.",
               },
             }
      }.to change { staff_notifications(admin, kind: "flag_note").count }.by(1)
      expect(response.status).to be_between(200, 299)

      data = JSON.parse(staff_notifications(admin, kind: "flag_note").last.data)
      expect(data["url"]).to eq("/review/#{reviewable.id}")
      expect(data["excerpt"]).to eq("Controller-path note body.")
      expect(data["display_username"]).to eq(moderator.username)
      expect(staff_notifications(moderator, kind: "flag_note").count).to eq(0)
    end

    it "still saves the ReviewableNote when the staff fan-out raises mid-flight" do
      sign_in(moderator)

      allow(DiscourseModCategories::StaffNotifier).to receive(:fan_out).and_raise(
        StandardError,
        "induced failure",
      )

      expect {
        post "/review/#{reviewable.id}/notes.json",
             params: {
               reviewable_note: {
                 content: "Survive the fan-out crash.",
               },
             }
      }.to change { ReviewableNote.where(reviewable_id: reviewable.id).count }.by(1)
      expect(response.status).to be_between(200, 299)
    end
  end
end
