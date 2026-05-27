# frozen_string_literal: true

require "rails_helper"

# Verifies the dedupe job removes core notifications (:replied,
# :posted, :quoted, :mentioned) for users who also got a custom
# mod_whisper notification for the same post — so a whisper-audience
# member who is also the topic author / a watcher doesn't see two
# bell rows for the same post.
RSpec.describe Jobs::DedupeModWhisperNotifications do
  fab!(:topic)
  fab!(:post_record) { Fabricate(:post, topic: topic) }
  fab!(:audience_user, :user)
  fab!(:other_user, :user)

  def make_notification(type:, user:, topic: topic, post_number: post_record.post_number)
    Notification.create!(
      notification_type: Notification.types[type],
      user_id: user.id,
      topic_id: topic.id,
      post_number: post_number,
      data: { topic_title: topic.title }.to_json,
    )
  end

  it "deletes :replied / :posted / :quoted / :mentioned for audience recipients" do
    replied = make_notification(type: :replied, user: audience_user)
    posted = make_notification(type: :posted, user: audience_user)
    quoted = make_notification(type: :quoted, user: audience_user)
    mentioned = make_notification(type: :mentioned, user: audience_user)
    # Sentinel: our custom whisper notification stays.
    whisper =
      Notification.create!(
        notification_type: Notification.types[:custom],
        user_id: audience_user.id,
        topic_id: topic.id,
        post_number: post_record.post_number,
        data: { mod_whisper: true }.to_json,
      )

    described_class.new.execute(post_id: post_record.id, recipient_ids: [audience_user.id])

    expect(Notification.where(id: replied.id)).to be_empty
    expect(Notification.where(id: posted.id)).to be_empty
    expect(Notification.where(id: quoted.id)).to be_empty
    expect(Notification.where(id: mentioned.id)).to be_empty
    expect(Notification.where(id: whisper.id)).to exist
  end

  it "does not touch notifications for users not in the recipient list" do
    other_replied = make_notification(type: :replied, user: other_user)

    described_class.new.execute(post_id: post_record.id, recipient_ids: [audience_user.id])

    expect(Notification.where(id: other_replied.id)).to exist
  end

  it "does not touch notifications for other posts in the topic" do
    other_post = Fabricate(:post, topic: topic)
    other_post_replied =
      make_notification(type: :replied, user: audience_user, post_number: other_post.post_number)

    described_class.new.execute(post_id: post_record.id, recipient_ids: [audience_user.id])

    expect(Notification.where(id: other_post_replied.id)).to exist
  end

  it "is a no-op when the post no longer exists" do
    expect {
      described_class.new.execute(post_id: 9_999_999, recipient_ids: [audience_user.id])
    }.not_to raise_error
  end

  it "is a no-op for an empty recipient list" do
    replied = make_notification(type: :replied, user: audience_user)

    described_class.new.execute(post_id: post_record.id, recipient_ids: [])

    expect(Notification.where(id: replied.id)).to exist
  end
end
