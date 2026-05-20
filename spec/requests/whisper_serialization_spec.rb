# frozen_string_literal: true

require "rails_helper"

# Verifies whisper posts are serialized into the topic stream only for the
# audience, and that the SQL query filter agrees with Guardian#can_see_post?.
RSpec.describe "Whisper serialization" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:target, :user)
  fab!(:participant, :user)
  fab!(:stranger, :user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, user: author) }
  fab!(:whisper_post) { Fabricate(:post, topic: topic, user: author) }
  fab!(:normal_post) { Fabricate(:post, topic: topic, user: stranger) }
  fab!(:group_member, :user)
  fab!(:whisper_group) { Fabricate(:group, name: "whisper_squad") }

  let(:targets_field) { DiscourseModCategories::POST_WHISPER_TARGETS_FIELD }
  let(:groups_field) do
    DiscourseModCategories::POST_WHISPER_TARGET_GROUPS_FIELD
  end
  let(:participants_field) do
    DiscourseModCategories::TOPIC_WHISPER_PARTICIPANTS_FIELD
  end

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    SiteSetting.auto_silence_fast_typers_on_first_post = false
    Group.refresh_automatic_groups!

    whisper_post.custom_fields[targets_field] = [target.id]
    whisper_post.save_custom_fields(true)

    topic.custom_fields[participants_field] = [target.id, participant.id]
    topic.save_custom_fields(true)
  end

  def stream_post_ids
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(200)
    response.parsed_body["post_stream"]["posts"].map { |p| p["id"] }
  end

  it "shows the whisper to the author" do
    sign_in(author)
    expect(stream_post_ids).to include(whisper_post.id)
  end

  it "shows the whisper to a target" do
    sign_in(target)
    expect(stream_post_ids).to include(whisper_post.id)
  end

  it "shows the whisper to a cumulative topic participant" do
    sign_in(participant)
    expect(stream_post_ids).to include(whisper_post.id)
  end

  it "shows the whisper to staff" do
    sign_in(admin)
    expect(stream_post_ids).to include(whisper_post.id)
    sign_in(moderator)
    expect(stream_post_ids).to include(whisper_post.id)
  end

  it "hides the whisper from a stranger" do
    sign_in(stranger)
    ids = stream_post_ids
    expect(ids).not_to include(whisper_post.id)
    expect(ids).to include(normal_post.id)
  end

  it "hides the whisper from an anonymous viewer" do
    expect(stream_post_ids).not_to include(whisper_post.id)
  end

  it "serializes whisper attributes for a viewer who can see it" do
    sign_in(target)
    get "/t/#{topic.id}.json"
    post_json =
      response.parsed_body["post_stream"]["posts"].find do |p|
        p["id"] == whisper_post.id
      end
    expect(post_json["mod_is_whisper"]).to eq(true)
    expect(post_json["mod_whisper_target_user_ids"]).to eq([target.id])
    expect(post_json["mod_whisper_targets"].map { |t| t["id"] }).to eq(
      [target.id],
    )
    expect(post_json["mod_whisper_is_staff_only"]).to eq(false)
    expect(post_json["mod_whisper_author_is_staff"]).to eq(false)
  end

  it "marks an empty-target whisper as staff-only" do
    whisper_post.custom_fields[targets_field] = []
    whisper_post.save_custom_fields(true)

    sign_in(admin)
    get "/t/#{topic.id}.json"
    post_json =
      response.parsed_body["post_stream"]["posts"].find do |p|
        p["id"] == whisper_post.id
      end
    expect(post_json["mod_is_whisper"]).to eq(true)
    expect(post_json["mod_whisper_is_staff_only"]).to eq(true)
  end

  it "exposes the topic whisper participant ids on the topic view" do
    sign_in(admin)
    get "/t/#{topic.id}.json"
    expect(response.parsed_body["mod_whisper_participant_ids"]).to match_array(
      [target.id, participant.id],
    )
  end

  describe "audience visibility" do
    # A whisper IS visible to every member of its audience: an explicit
    # target, a cumulative topic participant, and any staff member. Asserted
    # both via Guardian#can_see_post? and the topic-view JSON.
    [:target, :participant, :admin, :moderator, :author].each do |persona|
      it "is visible to #{persona} via Guardian and topic-view JSON" do
        user = send(persona)
        expect(
          Guardian.new(user).can_see_post?(whisper_post.reload),
        ).to eq(true)

        sign_in(user)
        expect(stream_post_ids).to include(whisper_post.id)
      end
    end

    # A whisper is NOT visible to a non-audience user.
    it "is not visible to a stranger via Guardian or topic-view JSON" do
      expect(
        Guardian.new(stranger).can_see_post?(whisper_post.reload),
      ).to eq(false)

      sign_in(stranger)
      expect(stream_post_ids).not_to include(whisper_post.id)
    end
  end

  describe "group-targeted whisper" do
    before do
      whisper_group.add(group_member)
      whisper_post.custom_fields[targets_field] = []
      whisper_post.custom_fields[groups_field] = [whisper_group.id]
      whisper_post.save_custom_fields(true)
    end

    it "shows the whisper to a member of the target group" do
      expect(
        Guardian.new(group_member).can_see_post?(whisper_post.reload),
      ).to eq(true)

      sign_in(group_member)
      expect(stream_post_ids).to include(whisper_post.id)
    end

    it "hides the whisper from a non-member non-staff user" do
      expect(
        Guardian.new(stranger).can_see_post?(whisper_post.reload),
      ).to eq(false)

      sign_in(stranger)
      expect(stream_post_ids).not_to include(whisper_post.id)
    end

    it "still shows the whisper to staff for oversight" do
      sign_in(admin)
      expect(stream_post_ids).to include(whisper_post.id)
    end

    it "serializes the target group on the post" do
      sign_in(group_member)
      get "/t/#{topic.id}.json"
      post_json =
        response.parsed_body["post_stream"]["posts"].find do |p|
          p["id"] == whisper_post.id
        end
      expect(post_json["mod_whisper_target_group_ids"]).to eq(
        [whisper_group.id],
      )
      expect(post_json["mod_whisper_target_groups"]).to eq(
        [{ "id" => whisper_group.id, "name" => whisper_group.name }],
      )
      # A group-targeted whisper is NOT staff-only.
      expect(post_json["mod_whisper_is_staff_only"]).to eq(false)
    end

    it "keeps Guardian and QueryFilter in parity across personas" do
      [nil, author, target, participant, stranger, group_member, admin].each do |user|
        guardian_visible =
          Guardian.new(user).can_see_post?(whisper_post.reload)
        sql_visible =
          DiscourseModCategories::WhisperQueryFilter
            .apply(Post.where(id: whisper_post.id), user)
            .exists?
        expect(sql_visible).to eq(guardian_visible),
        "QueryFilter (#{sql_visible}) disagrees with Guardian " \
          "(#{guardian_visible}) for user #{user&.username || "anonymous"}"
      end
    end
  end

  describe "Guardian <-> QueryFilter parity" do
    [nil, :author, :target, :participant, :stranger, :admin, :moderator].each do |persona|
      it "agrees for persona=#{persona || "anonymous"}" do
        user =
          case persona
          when nil
            nil
          else
            send(persona)
          end

        guardian_visible = Guardian.new(user).can_see_post?(whisper_post.reload)

        filtered =
          DiscourseModCategories::WhisperQueryFilter.apply(
            Post.where(id: whisper_post.id),
            user,
          )
        sql_visible = filtered.exists?

        expect(sql_visible).to eq(guardian_visible),
        "QueryFilter (#{sql_visible}) disagrees with Guardian " \
          "(#{guardian_visible}) for persona #{persona || "anonymous"}"
      end
    end

    it "agrees on a staff-only whisper-back across personas" do
      whisper_post.custom_fields[targets_field] = []
      whisper_post.save_custom_fields(true)

      [nil, author, target, participant, stranger, admin].each do |user|
        guardian_visible =
          Guardian.new(user).can_see_post?(whisper_post.reload)
        sql_visible =
          DiscourseModCategories::WhisperQueryFilter
            .apply(Post.where(id: whisper_post.id), user)
            .exists?
        expect(sql_visible).to eq(guardian_visible)
      end
    end
  end
end
