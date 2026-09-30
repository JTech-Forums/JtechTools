# frozen_string_literal: true

# The whisper checks run for every post on a topic page (Guardian and
# serializer); they must share one lookup instead of querying per post.
RSpec.describe "Whisper checks on a topic page" do
  fab!(:topic)
  fab!(:user)
  fab!(:moderator)

  before do
    SiteSetting.mod_categories_enabled = true
    SiteSetting.mod_whisper_enabled = true
    12.times { Fabricate(:post, topic: topic) }
    whisper = Fabricate(:post, topic: topic, user: moderator)
    whisper.custom_fields[DiscourseModCategories::POST_WHISPER_TARGETS_FIELD] = [user.id]
    whisper.save_custom_fields(true)
  end

  def custom_field_queries
    queries = track_sql_queries { get "/t/#{topic.id}.json" }
    expect(response.status).to eq(200)
    queries.count { |q| q.include?("post_custom_fields") }
  end

  it "doesn't query per post" do
    sign_in(user)
    few = custom_field_queries
    8.times { Fabricate(:post, topic: topic) }
    expect(custom_field_queries).to eq(few)
  end

  it "still hides the whisper from people outside its audience" do
    sign_in(Fabricate(:user))
    get "/t/#{topic.id}.json"
    ids = response.parsed_body["post_stream"]["posts"].map { |p| p["id"] }
    whisper_ids =
      PostCustomField.where(name: DiscourseModCategories::POST_WHISPER_TARGETS_FIELD).pluck(
        :post_id,
      )
    expect(ids & whisper_ids).to be_empty
  end
end
